import Testing
@testable import NextSet

@MainActor
struct SetProgressTests {
    private func snapshot(completed: Int, goal: Int = 0, finished: Bool = false,
                          single: Bool = false) -> TimerSnapshot {
        var settings = TimerSettings()
        settings.goalSets = goal
        settings.mode = single ? .single : .sets
        var session = TimerSession()
        session.completedSets = completed
        session.phase = finished ? .finished : .idle
        return TimerSnapshot(settings: settings, session: session)
    }

    @Test func unlimitedKeepsCurrentDotAtLargeCounts() {
        for count in [0, 1, 4, 5, 11, 12, 20, 99, 100, 1_000, 1_000_000] {
            let value = snapshot(completed: count)
            #expect(value.dots.count <= 5)
            #expect(value.dots.last == .current)
            #expect(value.dots.filter { $0 == .current }.count == 1)
            #expect(value.nextSetNumber == count + 1)
            #expect(value.session.completedSets == count)
        }
        #expect(snapshot(completed: 100).dots == [.past, .past, .past, .past, .current])
    }

    @Test func goalsKeepWindowAroundCurrentSet() {
        for goal in 1...20 {
            for completed in 0..<goal {
                let dots = snapshot(completed: completed, goal: goal).dots
                #expect(dots.count == min(5, goal))
                #expect(dots.filter { $0 == .current }.count == 1)
            }
        }
        #expect(snapshot(completed: 0, goal: 20).dots == [.current, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(snapshot(completed: 10, goal: 20).dots == [.past, .past, .current, .upcoming, .upcoming])
        #expect(snapshot(completed: 19, goal: 20).dots == [.past, .past, .past, .past, .current])
    }

    @Test func summariesStayBoundedAndSmallGoalsAreUnchanged() {
        #expect(snapshot(completed: 0, goal: 3).dots == [.current, .upcoming, .upcoming])
        #expect(snapshot(completed: 1, goal: 3).dots == [.past, .current, .upcoming])
        for count in [1, 5, 20, 100, 1_000_000] {
            let dots = snapshot(completed: count, finished: true).dots
            #expect(dots.count == min(5, count))
            #expect(dots.allSatisfy { $0 == .past })
        }
        #expect(snapshot(completed: 0, single: true).dots == [.current])
        #expect(snapshot(completed: 0, finished: true, single: true).dots == [.past])
    }

    @Test func oversizedGoalIsClampedBeforeRendering() {
        let value = snapshot(completed: 0, goal: 100)
        #expect(value.settings.goalSets == 20)
        #expect(value.dots.count == 5)
        #expect(value.dots.first == .current)
    }
}
