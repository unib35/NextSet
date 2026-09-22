import Foundation
import Testing
@testable import NextSet

@MainActor
struct WorkoutHistoryTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_000) }

    private func make(_ clock: Clock, defaults: UserDefaults) -> RestTimer {
        let activity = RestActivityController()
        activity.isEnabled = false
        return RestTimer(defaults: defaults, notifications: RestNotifications(isEnabled: false),
                         liveActivity: activity, clock: { clock.now })
    }

    @Test func earlyExitSavesPartialRestAndSurvivesRelaunch() throws {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let timer = make(clock, defaults: defaults)
        timer.start()
        clock.now += 17
        timer.endWorkout()
        let record = try #require(timer.history.first)
        #expect(record.completedSets == 0)
        #expect(record.restCount == 1)
        #expect(record.totalRested == 17)
        #expect(record.averageRest == 17)
        #expect(timer.session == TimerSession())
        timer.endWorkout()
        #expect(timer.history.count == 1)
        #expect(make(clock, defaults: defaults).history == [record])
    }

    @Test func pauseAndRestartCountActualRestOnly() throws {
        let clock = Clock()
        let timer = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        timer.start()
        clock.now += 20
        timer.togglePause()
        clock.now += 100
        timer.restartRest()
        clock.now += 15
        timer.endWorkout()
        let record = try #require(timer.history.first)
        #expect(record.totalRested == 35)
        #expect(record.restCount == 1)
    }

    @Test func idleExitExcludesTimeSpentDoingNextSet() throws {
        let clock = Clock()
        let timer = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        timer.start()
        clock.now += 60
        timer.tick()
        clock.now += 500
        timer.tick()
        #expect(timer.canEndWorkout)
        timer.endWorkout()
        let record = try #require(timer.history.first)
        #expect(record.totalRested == 60)
        #expect(record.completedSets == 1)
    }

    @Test func goalSavedOnceAndDeletingItDoesNotResurrectIt() {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let timer = make(clock, defaults: defaults)
        timer.settings.goalSets = 1
        timer.start()
        clock.now += 60
        timer.tick()
        #expect(timer.history.count == 1)
        #expect(timer.history.first?.reachedGoal == true)
        let remoteRecords = timer.history
        timer.deleteHistory(at: IndexSet(integer: 0))
        let restored = make(clock, defaults: defaults)
        restored.mergeHistory(remoteRecords)
        restored.startOver()
        #expect(restored.history.isEmpty)
    }

    @Test func singleRunsAreSeparateRecordsAndBoundedToThirty() {
        let clock = Clock()
        let timer = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        timer.selectMode(.single)
        timer.setRestSeconds(5)
        for _ in 0..<35 {
            timer.start()
            clock.now += 5
            timer.tick()
            clock.now += 2
            timer.tick()
        }
        #expect(timer.history.count == 30)
        #expect(Set(timer.history.map(\.id)).count == 30)
        #expect(timer.history.allSatisfy { $0.totalRested == 5 && $0.restCount == 1 && $0.completedSets == 0 })
        #expect(timer.history.first!.endedAt > timer.history.last!.endedAt)
    }

    @Test func skippedAndPartialRestAverageUsesRestCount() throws {
        let clock = Clock()
        let timer = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        timer.start()
        clock.now += 10
        timer.skip()
        clock.now += 2
        timer.start()
        clock.now += 20
        timer.endWorkout()
        let record = try #require(timer.history.first)
        #expect(record.totalRested == 30)
        #expect(record.restCount == 2)
        #expect(record.averageRest == 15)
        #expect(record.skippedCount == 1)
        #expect(record.completedSets == 1)
    }

    @Test func pairedHistoryPayloadMergesWithoutDuplicatesOrEcho() throws {
        let clock = Clock()
        let sender = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let receiver = make(clock, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        sender.start()
        clock.now += 12
        sender.endWorkout()
        let payload = RestSync.payload(settings: sender.settings, session: sender.session,
                                       sentAt: sender.lastChangedAt, history: sender.history)
        let data = try #require(payload["history"] as? Data)
        let records = try JSONDecoder().decode([WorkoutRecord].self, from: data)
        var changes = 0
        receiver.stateDidChange = { changes += 1 }
        receiver.mergeHistory(records)
        receiver.mergeHistory(records)
        #expect(receiver.history == sender.history)
        #expect(changes == 0)
    }

    @Test func legacySessionStillDecodes() throws {
        let json = #"{"phase":"idle","completedSets":2,"restDuration":60,"pausedRemaining":0,"totalRested":120,"skippedCount":0}"#
        let session = try JSONDecoder().decode(TimerSession.self, from: Data(json.utf8))
        #expect(session.completedSets == 2)
        #expect(session.workoutID == nil)
        #expect(session.historySaved == nil)
    }
}
