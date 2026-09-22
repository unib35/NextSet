import Foundation
import Testing
import UserNotifications
@testable import NextSet

@MainActor
struct RestNotificationTests {
    private let alert = RestNotifications.Alert(title: "Rest over", body: "Next set", isActionable: true)

    private final class FakeCenter {
        var status: UNAuthorizationStatus = .authorized
        var permissionRequests = 0
        var pending: [String: UNNotificationRequest] = [:]
        var holdPermission = false
        var permissionContinuation: CheckedContinuation<Bool, Never>?
        var holdAdd = false
        var addContinuation: CheckedContinuation<Void, Never>?
        var addCount = 0
        var failAt: Int?
        enum Failure: Error { case unavailable }

        var backend: RestNotifications.Backend {
            .init(status: { self.status }, request: {
                self.permissionRequests += 1
                if self.holdPermission {
                    let granted = await withCheckedContinuation { self.permissionContinuation = $0 }
                    self.status = granted ? .authorized : .denied
                    return granted
                }
                self.status = .authorized
                return true
            }, add: { request in
                self.addCount += 1
                if self.holdAdd {
                    self.holdAdd = false
                    await withCheckedContinuation { self.addContinuation = $0 }
                }
                if self.failAt == self.addCount { throw Failure.unavailable }
                self.pending[request.identifier] = request
            }, removePending: { ids in ids.forEach { self.pending.removeValue(forKey: $0) } },
            removeDelivered: { _ in })
        }
    }

    @Test func firstPermissionIsResolvedBeforeScheduling() async {
        let center = FakeCenter()
        center.status = .notDetermined
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(center.permissionRequests == 1)
        #expect(center.pending.count == 5)
        #expect(alerts.authorization == .authorized)
        #expect(center.pending["rest-end-0"]?.content.categoryIdentifier == "REST_END")
    }

    @Test func deniedPermissionDoesNotScheduleOrAskAgain() async {
        let center = FakeCenter()
        center.status = .denied
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .off, repeating: false)
        await alerts.waitForPendingOperations()
        #expect(center.pending.isEmpty)
        #expect(center.permissionRequests == 0)
        #expect(alerts.authorization == .denied)
    }

    @Test func endingDuringPermissionDialogDoesNotResurrectAlert() async throws {
        let center = FakeCenter()
        center.status = .notDetermined
        center.holdPermission = true
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        for _ in 0..<1000 {
            if center.permissionContinuation != nil { break }
            await Task.yield()
        }
        let continuation = try #require(center.permissionContinuation)
        alerts.cancelPending()
        continuation.resume(returning: true)
        await alerts.waitForPendingOperations()
        #expect(center.pending.isEmpty)
        #expect(center.addCount == 0)
    }

    @Test func changingTimeDuringAddLeavesOnlyNewestRequest() async throws {
        let center = FakeCenter()
        center.holdAdd = true
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        for _ in 0..<1000 {
            if center.addContinuation != nil { break }
            await Task.yield()
        }
        let continuation = try #require(center.addContinuation)
        alerts.schedule(.init(title: "Newest", body: "", isActionable: false), at: .now.addingTimeInterval(120), sound: .off, repeating: false)
        continuation.resume()
        await alerts.waitForPendingOperations()
        #expect(center.pending.count == 1)
        #expect(center.pending["rest-end-0"]?.content.title == "Newest")
        #expect(center.pending["rest-end-0"]?.content.sound == nil)
    }

    @Test func cancellingDuringAddRemovesLateCompletion() async throws {
        let center = FakeCenter()
        center.holdAdd = true
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: false)
        for _ in 0..<1000 {
            if center.addContinuation != nil { break }
            await Task.yield()
        }
        let continuation = try #require(center.addContinuation)
        alerts.cancelPending()
        continuation.resume()
        await alerts.waitForPendingOperations()
        #expect(center.pending.isEmpty)
    }

    @Test func partialFailureIsVisibleAndRetryRecovers() async {
        let center = FakeCenter()
        center.failAt = 2
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(alerts.schedulingFailed)
        #expect(center.pending.isEmpty)
        center.failAt = nil
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: false)
        await alerts.waitForPendingOperations()
        #expect(!alerts.schedulingFailed)
        #expect(center.pending.count == 1)
    }

    @Test func expiredRestIsNotScheduledAfterPermissionDelay() async {
        let center = FakeCenter()
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(-10), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(center.pending.isEmpty)
    }

    private func makeTimer(_ device: NotificationDevice, center: FakeCenter) -> RestTimer {
        let activity = RestActivityController()
        activity.isEnabled = false
        return RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                         notifications: RestNotifications(backend: center.backend),
                         liveActivity: activity, notificationDevice: device)
    }

    @Test func watchStartedRestSchedulesOnWatchAndNotOnPhone() async {
        let watchCenter = FakeCenter(), phoneCenter = FakeCenter()
        let watch = makeTimer(.watch, center: watchCenter)
        let phone = makeTimer(.phone, center: phoneCenter)
        watch.start()
        phone.adopt(settings: watch.settings, session: watch.session, changedAt: .now)
        await watch.notifications.waitForPendingOperations()
        await phone.notifications.waitForPendingOperations()
        #expect(watch.session.notificationDevice == .watch)
        #expect(!watchCenter.pending.isEmpty)
        #expect(phoneCenter.pending.isEmpty)
        watch.togglePause()
        await watch.notifications.waitForPendingOperations()
        #expect(watchCenter.pending.isEmpty)
        watch.togglePause()
        await watch.notifications.waitForPendingOperations()
        #expect(!watchCenter.pending.isEmpty)
        watch.endWorkout()
        await watch.notifications.waitForPendingOperations()
        #expect(watchCenter.pending.isEmpty)
    }

    @Test func soundAndRepeatChangesUpdatePendingAlerts() async {
        let center = FakeCenter()
        let timer = makeTimer(.phone, center: center)
        timer.start()
        await timer.notifications.waitForPendingOperations()
        #expect(center.pending.count == 5)
        timer.settings.sound = .off
        timer.settings.repeatAlert = false
        await timer.notifications.waitForPendingOperations()
        #expect(center.pending.count == 1)
        #expect(center.pending["rest-end-0"]?.content.sound == nil)
    }

    @Test func remotePhoneOwnershipCancelsExistingWatchAlertAndLegacyDecodes() async throws {
        let watchCenter = FakeCenter(), phoneCenter = FakeCenter()
        let watch = makeTimer(.watch, center: watchCenter)
        let phone = makeTimer(.phone, center: phoneCenter)
        watch.start()
        await watch.notifications.waitForPendingOperations()
        phone.start()
        var legacy = phone.session
        legacy.notificationDevice = nil
        let decoded = try JSONDecoder().decode(TimerSession.self, from: JSONEncoder().encode(legacy))
        watch.adopt(settings: phone.settings, session: decoded, changedAt: .now)
        await watch.notifications.waitForPendingOperations()
        await phone.notifications.waitForPendingOperations()
        #expect(watchCenter.pending.isEmpty)
        #expect(!phoneCenter.pending.isEmpty)
    }
}
