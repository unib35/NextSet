#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Live Activity(3f) / Dynamic Island(3g) 생명주기. `RestTimer`가 세션이 바뀔 때마다 `sync`를 부른다.
///
/// - 휴식이 시작되면 액티비티를 만들고, 운동이 이어지는 동안(세트가 하나라도 있으면) 유지한다.
/// - `endWorkout`/`startOver`(세션 초기화)에서 바로 지운다. 목표 달성(`finished`)은 "운동 완료"로 두고 시스템 정책으로 사라진다.
/// - 실행 중에는 `staleDate = endDate`. 앱이 잠들어도 위젯이 종료 시각에 "휴식 끝"으로 바꿔 그린다.
final class RestActivityController {
    private var activity: Activity<RestActivityAttributes>?
    var isEnabled = true

    init() {
        // 앱이 다시 켜졌을 때 이미 떠 있는 액티비티를 이어받는다.
        activity = Activity<RestActivityAttributes>.activities.first
    }

    func sync(settings: TimerSettings, session: TimerSession) {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard settings.liveActivity else {  // 4c "Live Activity" 끔
            if activity != nil { Task { await end(dismissal: .immediate) } }
            return
        }
        let state = RestActivityAttributes.ContentState(settings: settings, session: session)
        let content = ActivityContent(state: state, staleDate: session.phase == .running ? session.endDate : nil)

        let isActive = session.phase == .running || session.phase == .paused
        let inWorkout = isActive || session.completedSets > 0 || session.phase == .done
        Task {
            if session == TimerSession() {
                await end(dismissal: .immediate)
            } else if session.phase == .finished {
                await activity?.end(content, dismissalPolicy: .default)
                activity = nil
            } else if let activity, inWorkout {
                await activity.update(content)
            } else if isActive {
                do {
                    activity = try Activity.request(attributes: RestActivityAttributes(startedAt: .now), content: content)
                } catch {
                    activity = nil
                }
            }
        }
    }

    private func end(dismissal: ActivityUIDismissalPolicy) async {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: dismissal)
        }
        activity = nil
    }
}
#else
/// 워치에는 Live Activity 가 없다. 같은 인터페이스의 빈 구현.
final class RestActivityController {
    var isEnabled = true
    init() {}
    func sync(settings: TimerSettings, session: TimerSession) {}
}
#endif
