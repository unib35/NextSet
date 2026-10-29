import Foundation
import Testing
import UserNotifications
@testable import NextSet

/// T-88: iOS 26 휴식 끝 알람(AlarmKit). 실제 AlarmKit 대신 가짜 백엔드로 예약·취소 순서를 본다.
@MainActor
struct RestAlarmTests {
    private final class FakeAlarms {
        var status: RestAlarm.Authorization = .notDetermined
        var grant: RestAlarm.Authorization = .authorized
        var requests = 0
        var scheduled: [UUID: RestAlarm.Request] = [:]
        var failNext = false
        enum Failure: Error { case unavailable }

        var backend: RestAlarm.Backend {
            .init(status: { self.status },
                  request: { self.requests += 1; self.status = self.grant; return self.grant },
                  schedule: { id, request in
                      if self.failNext { self.failNext = false; throw Failure.unavailable }
                      self.scheduled[id] = request
                  },
                  cancel: { id in self.scheduled.removeValue(forKey: id) })
        }
        var only: RestAlarm.Request? { scheduled.count == 1 ? scheduled.values.first : nil }
    }

    private final class FakeNotifications {
        var pending: [String: UNNotificationRequest] = [:]
        var permissionRequests = 0
        var restPending: [String: UNNotificationRequest] { pending.filter { $0.key.hasPrefix("rest-end-") } }
        var backend: RestNotifications.Backend {
            .init(status: { .authorized }, request: { self.permissionRequests += 1; return true },
                  add: { self.pending[$0.identifier] = $0 },
                  removePending: { ids in ids.forEach { self.pending.removeValue(forKey: $0) } },
                  removeDelivered: { _ in })
        }
    }

    private func makeTimer(_ alarms: FakeAlarms, _ notes: FakeNotifications,
                           configure: (inout TimerSettings) -> Void = { _ in }) -> RestTimer {
        let activity = RestActivityController()
        activity.isEnabled = false
        let timer = RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                              notifications: RestNotifications(backend: notes.backend),
                              liveActivity: activity, notificationDevice: .phone,
                              alarm: RestAlarm(backend: alarms.backend))
        configure(&timer.settings)
        return timer
    }

    private func settle(_ timer: RestTimer) async {
        for _ in 0..<20 { await Task.yield() }
        await timer.alarm.waitForPendingOperations()
        await timer.notifications.waitForPendingOperations()
    }

    @Test func firstRestAsksAlarmPermissionAndRingsOnlyInBackground() async throws {
        let alarms = FakeAlarms(), notes = FakeNotifications()
        let timer = makeTimer(alarms, notes)
        timer.scenePhaseChanged(isActive: true)
        timer.start()
        await settle(timer)
        #expect(alarms.requests == 1)
        #expect(notes.permissionRequests == 0)  // 알람을 쓰면 알림 권한을 따로 묻지 않는다
        #expect(notes.restPending.isEmpty)
        #expect(alarms.scheduled.isEmpty)  // 앱을 보고 있으면 앱이 울린다

        timer.scenePhaseChanged(isActive: false)
        await settle(timer)
        let alarm = try #require(alarms.only)
        #expect(alarm.fireDate == timer.session.endDate)
        #expect(alarm.title == "휴식 끝 · 세트 2")
        #expect(alarm.snoozeLabel == "+30초 더 쉬기")
        #expect(notes.restPending.isEmpty)

        timer.scenePhaseChanged(isActive: true)
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
    }

    /// 앱이 뒤에서 살아 있어 타이머가 "휴식 끝"으로 넘어가도 막 울린 알람을 지우지 않는다. 앞으로 오면 지운다.
    @Test func naturalRestEndKeepsRingingAlarmUntilForeground() async throws {
        final class Clock { var now = Date.now }
        let clock = Clock()
        let alarms = FakeAlarms(), notes = FakeNotifications()
        alarms.status = .authorized
        let activity = RestActivityController()
        activity.isEnabled = false
        let timer = RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                              notifications: RestNotifications(backend: notes.backend),
                              liveActivity: activity, clock: { clock.now }, notificationDevice: .phone,
                              alarm: RestAlarm(backend: alarms.backend))
        timer.settings.restSeconds = 5
        timer.scenePhaseChanged(isActive: false)
        timer.start()
        await settle(timer)
        #expect(alarms.only != nil)

        try await Task.sleep(for: .seconds(5.2))  // 실제 시각이 알람 시각을 넘어야 "이미 울리는 중"이다
        clock.now = .now
        timer.tick()
        await settle(timer)
        #expect(timer.session.phase == .done)
        #expect(alarms.only != nil, "울리기 시작한 알람을 앱이 지우면 안 된다")

        timer.scenePhaseChanged(isActive: true)
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
    }

    @Test func pauseSkipAndEndCancelTheBackgroundAlarm() async throws {
        let alarms = FakeAlarms(), notes = FakeNotifications()
        alarms.status = .authorized
        let timer = makeTimer(alarms, notes)
        timer.scenePhaseChanged(isActive: false)  // 위젯·잠금화면 버튼으로 앱이 뒤에서 깨어난 경우
        timer.start()
        await settle(timer)
        let first = try #require(alarms.only)

        timer.adjustRemaining(by: 30)
        await settle(timer)
        #expect(try #require(alarms.only).fireDate == first.fireDate.addingTimeInterval(30))

        timer.togglePause()
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
        timer.togglePause()
        await settle(timer)
        #expect(alarms.only != nil)

        timer.skip()
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
        timer.start()
        timer.endWorkout()
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
    }

    @Test func soundOffOrDeniedFallsBackToNotifications() async {
        let alarms = FakeAlarms(), notes = FakeNotifications()
        alarms.status = .authorized
        let timer = makeTimer(alarms, notes)
        timer.scenePhaseChanged(isActive: false)
        timer.start()
        await settle(timer)
        #expect(alarms.scheduled.count == 1)
        #expect(notes.restPending.isEmpty)

        timer.settings.sound = .off  // 소리를 끈 사람에게 알람을 울리지 않는다
        await settle(timer)
        #expect(alarms.scheduled.isEmpty)
        #expect(notes.restPending.count == 1)

        let deniedAlarms = FakeAlarms(), deniedNotes = FakeNotifications()
        deniedAlarms.grant = .denied
        let denied = makeTimer(deniedAlarms, deniedNotes)
        denied.scenePhaseChanged(isActive: false)
        denied.start()
        await settle(denied)
        #expect(deniedAlarms.requests == 1)
        #expect(deniedAlarms.scheduled.isEmpty)
        #expect(deniedNotes.restPending.count == 1)
    }

    @Test func finalGoalRestHasNoSnoozeAndUnavailableNeverAsks() async throws {
        let alarms = FakeAlarms(), notes = FakeNotifications()
        alarms.status = .authorized
        let timer = makeTimer(alarms, notes) { $0.goalSets = 1 }
        timer.scenePhaseChanged(isActive: false)
        timer.start()
        await settle(timer)
        let alarm = try #require(alarms.only)
        #expect(alarm.title == "운동 완료")
        #expect(alarm.snoozeLabel == nil)

        let ios18 = RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                              notifications: RestNotifications(backend: notes.backend),
                              liveActivity: { let a = RestActivityController(); a.isEnabled = false; return a }(),
                              notificationDevice: .phone, alarm: RestAlarm(backend: .unavailable))
        ios18.scenePhaseChanged(isActive: false)
        ios18.start()
        await settle(ios18)
        #expect(!ios18.usesRestAlarm)
        #expect(ios18.restAlarmRequest == nil)
    }

    @Test func failedSchedulingIsVisible() async {
        let alarms = FakeAlarms(), notes = FakeNotifications()
        alarms.status = .authorized
        alarms.failNext = true
        let timer = makeTimer(alarms, notes)
        timer.scenePhaseChanged(isActive: false)
        timer.start()
        await settle(timer)
        #expect(timer.alarm.schedulingFailed)
        #expect(alarms.scheduled.isEmpty)
    }
}
