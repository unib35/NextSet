import Foundation
import Observation

/// 첫 실행 힌트(시안 6c·6d). 온보딩 화면은 없고, 힌트 세 개를 각각 한 번만 보여준다.
/// - 첫 휴식 중: 잠금화면·Dynamic Island 힌트 (RunningView)
/// - 첫 운동 종료 후: Apple Watch 안내 — 페어링된 경우만 (SetupView)
/// - 두 번째 운동 종료 후: "위젯 추가하는 방법" 안내 (SetupView → WidgetGuideView)
@Observable
final class FirstRunHints {
    @ObservationIgnored private let defaults: UserDefaults

    private(set) var lockScreenSeen: Bool
    private(set) var watchSeen: Bool
    private(set) var widgetGuideSeen: Bool

    init(defaults: UserDefaults = TimerStore.shared) {
        self.defaults = defaults
        lockScreenSeen = defaults.bool(forKey: TimerStore.Keys.hintLockScreen)
        watchSeen = defaults.bool(forKey: TimerStore.Keys.hintWatch)
        widgetGuideSeen = defaults.bool(forKey: TimerStore.Keys.hintWidgetGuide)
    }

    func markLockScreenSeen() { lockScreenSeen = true; defaults.set(true, forKey: TimerStore.Keys.hintLockScreen) }
    func markWatchSeen() { watchSeen = true; defaults.set(true, forKey: TimerStore.Keys.hintWatch) }
    func markWidgetGuideSeen() { widgetGuideSeen = true; defaults.set(true, forKey: TimerStore.Keys.hintWidgetGuide) }

    /// 첫 휴식 중 한 번.
    func showsLockScreenHint(endedWorkouts: Int) -> Bool { !lockScreenSeen && endedWorkouts == 0 }
    /// 첫 운동 종료 후, 워치가 페어링된 경우만.
    func showsWatchHint(endedWorkouts: Int, isWatchPaired: Bool) -> Bool { !watchSeen && endedWorkouts >= 1 && isWatchPaired }
    /// 두 번째 운동 종료 후.
    func showsWidgetGuideHint(endedWorkouts: Int) -> Bool { !widgetGuideSeen && endedWorkouts >= 2 }
}
