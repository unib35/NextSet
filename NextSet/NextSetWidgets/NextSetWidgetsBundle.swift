import SwiftUI
import WidgetKit

/// 위젯 익스텐션 진입점. 위젯은 앱과 `TimerStore.shared`(App Group)를 통해 상태를 공유한다.
/// 상태가 바뀌면 앱(`RestTimer`)이 `WidgetCenter.reloadAllTimelines()`를 불러 준다.
@main
struct NextSetWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWidget()
        HomeWidget()
        RestLiveActivity()
        RestControl()
    }
}
