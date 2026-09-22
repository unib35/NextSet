import SwiftUI
import WidgetKit

/// 워치 컴플리케이션 / 스마트 스택 (4g). 위젯 코드는 iOS 잠금화면 위젯과 같은 파일(`NextSetWidgets/LockScreenWidget.swift`)을 쓴다.
/// 상태는 워치의 App Group 저장소 — 워치 앱이 `RestSync`로 폰과 맞춘 값이다.
@main
struct NextSetWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWidget()
    }
}
