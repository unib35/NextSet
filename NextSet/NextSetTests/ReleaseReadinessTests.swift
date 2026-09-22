import Foundation
import Testing
@testable import NextSet

@MainActor
struct ReleaseReadinessTests {
    private func timer() -> RestTimer {
        let activity = RestActivityController()
        activity.isEnabled = false
        return RestTimer(defaults: UserDefaults(suiteName: UUID().uuidString)!,
                         notifications: RestNotifications(isEnabled: false), liveActivity: activity)
    }

    @Test func extremeExternalAddCannotPoisonSavedSession() {
        let timer = timer()
        timer.start()
        timer.handleURL(URL(string: "nextset://add?seconds=\(Int.max)")!)
        #expect(timer.displaySeconds <= 60)
        #expect(timer.session.restDuration == 60)
        timer.handleURL(URL(string: "nextset://add?seconds=\(Int.min)")!)
        #expect(timer.session.restDuration == 60)
        timer.togglePause()
        for _ in 0..<200 { timer.adjustRemaining(by: 600) }
        #expect(timer.session.restDuration == TimerValidation.maxRest)
        #expect(timer.displaySeconds <= Int(TimerValidation.maxRest))
    }

    @Test func malformedStoredSettingsAreBoundedAndRemovedSettingIsIgnored() throws {
        let data = Data(#"{"restSeconds":-5,"recentSeconds":9223372036854775807,"goalSets":-1,"autoDetectSetEnd":true}"#.utf8)
        let settings = try JSONDecoder().decode(TimerSettings.self, from: data)
        #expect(settings.restSeconds == 5)
        #expect(settings.recentSeconds == 600)
        #expect(settings.goalSets == 0)
        let encoded = try JSONEncoder().encode(settings)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("autoDetectSetEnd"))
    }

    @Test func corruptSessionsRecoverBeforeRendering() {
        var session = TimerSession()
        session.phase = .running
        session.restDuration = 60
        #expect(session.validated() == TimerSession()) // 종료 시각 없음
        session.endDate = .now.addingTimeInterval(60)
        session.completedSets = Int.max
        let snapshot = TimerSnapshot(settings: TimerSettings(), session: session)
        #expect(snapshot.session == TimerSession())
        #expect(snapshot.nextSetNumber == 1)
        #expect(snapshot.dots == [.current])
        session.completedSets = 0
        session.phase = .paused
        session.pausedRemaining = .infinity
        #expect(session.validated() == TimerSession())
    }

    @Test func oldPausedValueDoesNotInvalidateResumedSession() {
        var session = TimerSession()
        session.phase = .running
        session.restDuration = 10
        session.endDate = .now.addingTimeInterval(10)
        session.pausedRemaining = 50
        #expect(session.validated().phase == .running)
        #expect(session.validated().pausedRemaining == 0)
    }

    @Test func invalidRemoteSessionAndSettingsAreValidated() {
        let timer = timer()
        var settings = TimerSettings()
        settings.restSeconds = Int.max
        settings.goalSets = -1
        var session = TimerSession()
        session.phase = .paused
        session.pausedRemaining = -1
        timer.adopt(settings: settings, session: session, changedAt: .now)
        #expect(timer.settings.restSeconds == 600)
        #expect(timer.settings.goalSets == 0)
        #expect(timer.session.phase == .idle)
        #expect(timer.displaySeconds == 600)
    }

    @Test func expiredWidgetCountsCompletedRestAndGoal() {
        let now = Date.now
        var settings = TimerSettings()
        var session = TimerSession()
        session.phase = .running
        session.restDuration = 60
        session.endDate = now.addingTimeInterval(-1)
        #expect(RestDisplay.from(TimerSnapshot(settings: settings, session: session), at: now) == .ended(nextSet: 2))
        settings.goalSets = 1
        #expect(RestDisplay.from(TimerSnapshot(settings: settings, session: session), at: now) == .finished)
        settings.mode = .single
        #expect(RestDisplay.from(TimerSnapshot(settings: settings, session: session), at: now) == .finished)
    }

    @Test func controlRequestsAreIdempotent() {
        let timer = timer()
        timer.perform(.setControlRunning(false))
        #expect(timer.session.phase == .idle)
        timer.perform(.setControlRunning(true))
        let end = timer.session.endDate
        timer.perform(.setControlRunning(true))
        #expect(timer.session.phase == .running)
        #expect(timer.session.endDate == end)
        timer.perform(.setControlRunning(false))
        timer.perform(.setControlRunning(false))
        #expect(timer.session.phase == .paused)
        timer.perform(.setControlRunning(true))
        #expect(timer.session.phase == .running)
    }

    @Test func unsafeNumbersCanBeFormattedWithoutTrapping() {
        #expect(RestTimer.format(.infinity) == "0:00")
        #expect(formatRemaining(.nan) == "0:00")
        #expect(RestTimer.format(-1) == "0:00")
        #expect(!RestTimer.format(Double(Int.max)).isEmpty)
    }

    @Test func privacyResourcesShipWithApp() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect(PrivacyPolicyView.content.contains("jm.jongminlee@gmail.com"))
    }
}
