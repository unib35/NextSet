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
        var restPending: [String: UNNotificationRequest] { pending.filter { $0.key.hasPrefix("rest-end-") } }
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

    @Test func firstPermissionIsResolvedBeforeScheduling() async throws {
        let center = FakeCenter()
        // 이전 버전의 3~5번째 알림이 남아 있어도 재예약 시 제거해야 한다.
        for index in 2...4 {
            let id = "rest-end-\(index)"
            center.pending[id] = UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(), trigger: nil)
        }
        center.status = .notDetermined
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(center.permissionRequests == 1)
        #expect(center.restPending.count == 2)
        #expect(Set(center.restPending.keys) == ["rest-end-0", "rest-end-1"])
        let first = try #require(center.restPending["rest-end-0"]?.trigger as? UNTimeIntervalNotificationTrigger)
        let extra = try #require(center.restPending["rest-end-1"]?.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(abs(extra.timeInterval - first.timeInterval - 30) < 1)
        #expect(!first.repeats && !extra.repeats)
        #expect(alerts.authorization == .authorized)
        #expect(center.restPending["rest-end-0"]?.content.categoryIdentifier == "REST_END")
    }

    /// T-90(시안 A4): 휴식 끝은 시간 민감 알림, 한 시간 확인 알림은 보통 알림.
    @Test func restEndIsTimeSensitiveButReminderIsNot() async throws {
        let center = FakeCenter()
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        alerts.scheduleWorkoutReminder(at: .now.addingTimeInterval(3600), sound: .on)
        await alerts.waitForPendingOperations()
        #expect(center.restPending.count == 2)
        #expect(center.restPending.values.allSatisfy { $0.content.interruptionLevel == .timeSensitive })
        let reminder = try #require(center.pending[RestNotifications.workoutReminderIdentifier])
        #expect(reminder.content.interruptionLevel == .active)
    }

    @Test func deniedPermissionDoesNotScheduleOrAskAgain() async {
        let center = FakeCenter()
        center.status = .denied
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .off, repeating: false)
        await alerts.waitForPendingOperations()
        #expect(center.restPending.isEmpty)
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
        #expect(center.restPending.isEmpty)
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
        #expect(center.restPending.count == 1)
        #expect(center.restPending["rest-end-0"]?.content.title == "Newest")
        #expect(center.restPending["rest-end-0"]?.content.sound == nil)
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
        #expect(center.restPending.isEmpty)
    }

    @Test func partialFailureIsVisibleAndRetryRecovers() async {
        let center = FakeCenter()
        center.failAt = 2
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(alerts.schedulingFailed)
        #expect(center.restPending.isEmpty)
        center.failAt = nil
        alerts.schedule(alert, at: .now.addingTimeInterval(60), sound: .on, repeating: false)
        await alerts.waitForPendingOperations()
        #expect(!alerts.schedulingFailed)
        #expect(center.restPending.count == 1)
    }

    @Test func expiredRestIsNotScheduledAfterPermissionDelay() async {
        let center = FakeCenter()
        let alerts = RestNotifications(backend: center.backend)
        alerts.schedule(alert, at: .now.addingTimeInterval(-10), sound: .on, repeating: true)
        await alerts.waitForPendingOperations()
        #expect(center.restPending.isEmpty)
    }

    private final class Clock {
        var now = Date.now.addingTimeInterval(10)
    }

    private func reminderDate(_ center: FakeCenter) throws -> Date {
        let request = try #require(center.pending[RestNotifications.workoutReminderIdentifier])
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(request.content.categoryIdentifier.isEmpty) // 탭은 앱을 열고, 운동을 자동 종료하지 않는다.
        return Date.now.addingTimeInterval(trigger.timeInterval)
    }

    @Test func reminderWaitsForInitialRestPermissionAndRespectsDenial() async {
        for status in [UNAuthorizationStatus.notDetermined, .denied] {
            let center = FakeCenter()
            center.status = status
            let timer = makeTimer(.phone, center: center)
            timer.start()
            await timer.notifications.waitForPendingOperations()
            #expect((center.pending[RestNotifications.workoutReminderIdentifier] != nil) == (status == .notDetermined))
            #expect(center.permissionRequests == (status == .notDetermined ? 1 : 0))
            timer.endWorkout()
            await timer.notifications.waitForPendingOperations()
            #expect(center.pending.isEmpty)
        }
    }

    @Test func workoutReminderFollowsSetProgressAndCancelsOnEnd() async throws {
        let center = FakeCenter(), clock = Clock()
        let activity = RestActivityController()
        activity.isEnabled = false
        let timer = RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                              notifications: RestNotifications(backend: center.backend),
                              liveActivity: activity, clock: { clock.now })
        await timer.notifications.waitForPendingOperations()
        #expect(center.pending.isEmpty) // 시작하지 않은 앱에는 확인 알림이 없다.
        timer.start()
        await timer.notifications.waitForPendingOperations()
        #expect(abs(try reminderDate(center).timeIntervalSince(clock.now.addingTimeInterval(3660))) < 2)
        timer.togglePause()
        await timer.notifications.waitForPendingOperations()
        #expect(abs(try reminderDate(center).timeIntervalSince(clock.now.addingTimeInterval(3600))) < 2)
        #expect(center.restPending.isEmpty)
        clock.now += 120
        timer.skip()
        await timer.notifications.waitForPendingOperations()
        #expect(timer.session.completedSets == 1)
        #expect(timer.session.lastSetProgressAt == clock.now)
        let expected = clock.now.addingTimeInterval(3600)
        #expect(abs(try reminderDate(center).timeIntervalSince(expected)) < 2)
        clock.now += 300
        timer.goToSetup()
        timer.scenePhaseChanged(isActive: true)
        await timer.notifications.waitForPendingOperations()
        #expect(abs(try reminderDate(center).timeIntervalSince(expected)) < 2) // 앱 열기로 한 시간을 미루지 않는다.
        timer.endWorkout()
        await timer.notifications.waitForPendingOperations()
        #expect(center.pending.isEmpty)
    }

    @Test func backgroundCompletionReminderRestoresWithoutAnotherHourDelay() async throws {
        let center = FakeCenter(), clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let activity = RestActivityController()
        activity.isEnabled = false
        let first = RestTimer(defaults: defaults, notifications: RestNotifications(backend: center.backend),
                              liveActivity: activity, clock: { clock.now })
        first.start()
        await first.notifications.waitForPendingOperations()
        let expected = clock.now.addingTimeInterval(3660)
        clock.now += 600
        let restored = RestTimer(defaults: defaults, notifications: RestNotifications(backend: center.backend),
                                 liveActivity: activity, clock: { clock.now })
        await restored.notifications.waitForPendingOperations()
        #expect(restored.session.completedSets == 1)
        #expect(abs(try reminderDate(center).timeIntervalSince(expected)) < 2)
        restored.endWorkout()
        await restored.notifications.waitForPendingOperations()
    }

    @Test func extendingRestPastAnHourDoesNotPostponeReminderIndefinitely() async throws {
        let center = FakeCenter(), clock = Clock()
        let activity = RestActivityController()
        activity.isEnabled = false
        let timer = RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                              notifications: RestNotifications(backend: center.backend),
                              liveActivity: activity, clock: { clock.now })
        timer.start()
        for _ in 0..<7 { timer.adjustRemaining(by: 600) }
        await timer.notifications.waitForPendingOperations()
        #expect(abs(try reminderDate(center).timeIntervalSince(clock.now.addingTimeInterval(3600))) < 2)
        timer.endWorkout()
        await timer.notifications.waitForPendingOperations()
    }

    @Test func singleAndFinalGoalDoNotScheduleWorkoutReminder() async {
        for single in [true, false] {
            let center = FakeCenter()
            let timer = makeTimer(.phone, center: center)
            if single { timer.selectMode(.single) } else { timer.settings.goalSets = 1 }
            timer.start()
            await timer.notifications.waitForPendingOperations()
            #expect(center.pending[RestNotifications.workoutReminderIdentifier] == nil)
            #expect(center.restPending.count == 1)
            timer.endWorkout()
            await timer.notifications.waitForPendingOperations()
        }
    }

    @Test func expiredReminderDoesNotRepeatAndCancellationWinsLateAdd() async throws {
        let center = FakeCenter()
        let alerts = RestNotifications(backend: center.backend)
        alerts.scheduleWorkoutReminder(at: .now.addingTimeInterval(-1), sound: .on)
        await alerts.waitForPendingOperations()
        #expect(center.pending.isEmpty)
        center.holdAdd = true
        alerts.scheduleWorkoutReminder(at: .now.addingTimeInterval(3600), sound: .off)
        for _ in 0..<1000 {
            if center.addContinuation != nil { break }
            await Task.yield()
        }
        let continuation = try #require(center.addContinuation)
        alerts.scheduleWorkoutReminder(at: nil, sound: .off)
        continuation.resume()
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
        #expect(!watchCenter.restPending.isEmpty)
        #expect(phoneCenter.pending.isEmpty)
        #expect(watchCenter.pending[RestNotifications.workoutReminderIdentifier] != nil)
        watch.togglePause()
        await watch.notifications.waitForPendingOperations()
        #expect(watchCenter.restPending.isEmpty)
        watch.togglePause()
        await watch.notifications.waitForPendingOperations()
        #expect(!watchCenter.restPending.isEmpty)
        watch.endWorkout()
        await watch.notifications.waitForPendingOperations()
        #expect(watchCenter.restPending.isEmpty)
    }

    @Test func soundAndRepeatChangesUpdatePendingAlerts() async {
        let center = FakeCenter()
        let timer = makeTimer(.phone, center: center)
        timer.start()
        await timer.notifications.waitForPendingOperations()
        #expect(!timer.settings.repeatAlert)
        #expect(center.restPending.count == 1)
        timer.settings.repeatAlert = true
        await timer.notifications.waitForPendingOperations()
        #expect(center.restPending.count == 2)
        timer.settings.sound = .off
        timer.settings.repeatAlert = false
        await timer.notifications.waitForPendingOperations()
        #expect(center.restPending.count == 1)
        #expect(center.restPending["rest-end-0"]?.content.sound == nil)
    }

    /// T-83: 휴식 중 목표를 바꿔 이번 휴식이 마지막이 되면 종료 알림도 "운동 완료"로 다시 예약한다.
    @Test func goalChangeDuringRestUpdatesPendingAlert() async {
        let center = FakeCenter()
        let timer = makeTimer(.phone, center: center)
        timer.start()
        timer.skip()
        timer.start()
        await timer.notifications.waitForPendingOperations()
        #expect(center.restPending["rest-end-0"]?.content.categoryIdentifier == "REST_END")
        timer.adjustGoal(by: 1)  // 무제한 → 2세트: 이번 휴식이 끝나면 목표 달성
        await timer.notifications.waitForPendingOperations()
        #expect(center.restPending.count == 1)
        #expect(center.restPending["rest-end-0"]?.content.categoryIdentifier == "")
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
        #expect(phoneCenter.pending[RestNotifications.workoutReminderIdentifier] != nil)
        #expect(!phoneCenter.restPending.isEmpty)
    }
}
