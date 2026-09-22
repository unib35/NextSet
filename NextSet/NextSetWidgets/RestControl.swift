import AppIntents
import SwiftUI
import WidgetKit

/// 5a 제어 센터 컨트롤 — 탭 = 시작 / 일시정지. 실행 중엔 남은 시간을 보여준다.
/// 제어 센터는 컨트롤 하나에 버튼 하나라 시안의 "중형: 건너뛰기"는 넣지 못했다 (`docs/DECISIONS.md`).
struct RestControl: ControlWidget {
    static let kind = "kr.co.lee.NextSet.control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: RestControlProvider()) { value in
            ControlWidgetToggle(isOn: value.isRunning, action: ToggleRestControlIntent()) {
                Label(value.title, systemImage: value.isRunning ? "pause.fill" : "play.fill")
            }
            .tint(.orange)
        }
        .displayName("NextSet")
        .description("Tap to start rest. Tap again to pause.")
    }
}

struct RestControlValue {
    var isRunning: Bool
    var title: String
}

struct RestControlProvider: ControlValueProvider {
    var previewValue: RestControlValue { RestControlValue(isRunning: false, title: String(localized: "60s")) }

    func currentValue() async throws -> RestControlValue {
        let snapshot = TimerSnapshot()
        switch RestDisplay.from(snapshot, at: .now) {
        case .running(let end):
            return RestControlValue(isRunning: true, title: formatRemaining(end.timeIntervalSinceNow))
        case .paused(let remaining):
            return RestControlValue(isRunning: false, title: String(localized: "Paused \(formatRemaining(remaining))"))
        case .ended(let nextSet):
            return RestControlValue(isRunning: false, title: String(localized: "Start set \(nextSet)"))
        case .finished:
            return RestControlValue(isRunning: false, title: String(localized: "Workout complete"))
        case .idle(let seconds):
            return RestControlValue(isRunning: false, title: String(localized: "\(seconds)s"))
        }
    }
}
