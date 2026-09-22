import ActivityKit
import Foundation

/// 3f/3g Live Activity 의 데이터. 상태는 앱의 설정+세션을 그대로 실어 위젯이 `TimerSnapshot`으로 같은 계산을 한다.
///
/// 앱이 잠든 사이 휴식이 끝나면 앱이 update 를 못 하므로, `staleDate = endDate`로 두고
/// 위젯 쪽에서 `context.isStale`이면 "휴식 끝"으로 그린다.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var settings: TimerSettings
        var session: TimerSession

        var snapshot: TimerSnapshot { TimerSnapshot(settings: settings, session: session) }
    }

    /// 액티비티를 시작한 시각. 구분용.
    var startedAt: Date
}
