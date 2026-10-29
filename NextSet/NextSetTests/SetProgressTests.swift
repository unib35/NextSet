import Foundation
import Testing
@testable import NextSet

@MainActor
struct SetProgressTests {
    private func snapshot(completed: Int, goal: Int = 0, finished: Bool = false,
                          single: Bool = false, resting: Bool = false) -> TimerSnapshot {
        var settings = TimerSettings()
        settings.goalSets = goal
        settings.mode = single ? .single : .sets
        var session = TimerSession()
        session.completedSets = completed
        session.phase = finished ? .finished : .idle
        if resting {
            session.phase = .running
            session.restDuration = 60
            session.endDate = .now.addingTimeInterval(60)
        }
        return TimerSnapshot(settings: settings, session: session)
    }

    @Test func unlimitedPreservesEverySetAndFocusesNextSet() {
        for count in [1, 7, 99, 100, 1_000, 1_000_000] {
            let value = snapshot(completed: count)
            #expect(value.dots.count == count + 1)
            #expect(value.dots.last == .current)
            #expect(value.dots.focusIndex == count)
            #expect(value.dots.pastCount == count)
            if count > 0 { #expect(value.dots[count - 1] == .past) }
        }
    }

    /// 2026-10 시안: 0세트·카운트다운은 점을 숨기고, 휴식 중에는 방금 끝낸 세트까지 센다.
    @Test func zeroSetsHideDotsAndRestCountsJustFinishedSet() {
        #expect(snapshot(completed: 0).dots.isEmpty)
        #expect(snapshot(completed: 0).setCaption == "세트 시작 전")
        let firstRest = snapshot(completed: 0, resting: true)
        #expect(Array(firstRest.dots) == [.past, .current])
        #expect(firstRest.setCaption == "세트 1 완료")
        #expect(firstRest.nextSetNumber == 1)  // 세트 수 자체는 휴식이 끝날 때 오른다
        let goalRest = snapshot(completed: 2, goal: 4, resting: true)
        #expect(goalRest.setCaption == "세트 3/4")
        #expect(goalRest.dots.pastCount == 3)
        #expect(snapshot(completed: 0, single: true, resting: true).dots.isEmpty)
    }

    @Test func goalsHaveOneDotPerSet() {
        for goal in 1...20 {
            for completed in 0..<goal {
                let dots = snapshot(completed: completed, goal: goal).dots
                #expect(dots.count == goal)
                #expect(dots.filter { $0 == .past }.count == completed)
                #expect(dots[completed] == .current)
                #expect(dots.filter { $0 == .upcoming }.count == goal - completed - 1)
                #expect(dots.focusIndex == completed)
            }
        }
        #expect(snapshot(completed: 3, goal: 7).dots.count == 7)
    }

    @Test func summaryPreservesAllCompletedSetsAndFocusesLast() {
        for count in [1, 7, 100, 1_000_000] {
            let dots = snapshot(completed: count, finished: true).dots
            #expect(dots.count == count)
            #expect(dots.first == .past)
            #expect(dots.last == .past)
            #expect(dots.focusIndex == count - 1)
        }
        #expect(snapshot(completed: 0, single: true).dots.isEmpty)
        #expect(snapshot(completed: 0, finished: true, single: true).dots.isEmpty)
        #expect(snapshot(completed: 0, finished: true).dots.isEmpty)  // 3d: 점 수 = 세트 수
    }

    @Test func oversizedGoalStillUsesExistingLimit() {
        let value = snapshot(completed: 0, goal: 100)
        #expect(value.settings.goalSets == 20)
        #expect(value.dots.count == 20)
    }
}
