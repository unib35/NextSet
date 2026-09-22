import ActivityKit
import SwiftUI
import WidgetKit

/// 3f 잠금화면 Live Activity + 3g Dynamic Island.
/// 상태는 `context.state.snapshot`. 앱이 잠든 채 종료 시각이 지나면 `context.isStale` → "휴식 끝"으로 그린다.
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            let display = display(for: context)
            let snapshot = context.state.snapshot
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BigNumberLabel(display: display, referenceDate: .now, size: 44)
                        .frame(minWidth: 96, alignment: .leading)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 오른쪽 영역은 좁다. 짧은 제목 + 세트 캡션 (잠금화면 카드의 긴 제목은 `phaseTitle`).
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(shortPhaseTitle(display))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(snapshot.setCaption)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .lineLimit(1)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityButtons(display: display, height: 36)
                        .padding(.top, 6)
                }
            } compactLeading: {
                WidgetSetDots(dots: snapshot.dots, size: 5)
                    .padding(.leading, 4)
            } compactTrailing: {
                CompactTimerLabel(display: display)
                    .padding(.trailing, 2)
            } minimal: {
                CompactTimerLabel(display: display, minimal: true)
            }
            .keylineTint(.brand)
        }
    }

    private func display(for context: ActivityViewContext<RestActivityAttributes>) -> RestDisplay {
        RestDisplay.from(context.state.snapshot, at: .now, isStale: context.isStale)
    }
}

/// Dynamic Island 확장 뷰용 짧은 제목 (3g 의 phaseTitle).
func shortPhaseTitle(_ display: RestDisplay) -> String {
    switch display {
    case .finished: String(localized: "Finished")
    case .ended: String(localized: "Rest over")
    case .paused: String(localized: "Paused")
    case .running: String(localized: "Resting")
    case .idle: String(localized: "Idle")
    }
}

/// 시안 3f 의 laTitle.
func phaseTitle(_ display: RestDisplay, snapshot: TimerSnapshot) -> String {
    switch display {
    case .finished: String(localized: "Workout complete")
    case .ended(let nextSet): String(localized: "Rest over · Set \(nextSet)")
    case .paused: String(localized: "Paused")
    case .running: String(localized: "Resting")
    case .idle: snapshot.session.completedSets > 0 ? String(localized: "Set \(snapshot.session.completedSets) complete · Ready") : String(localized: "Ready to rest")
    }
}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        let card = LiveActivityCard(state: context.state, isStale: context.isStale)
        card
            .activityBackgroundTint(card.backgroundColor)
            .activitySystemActionForegroundColor(card.isEnded ? .black : .white)
    }
}

/// 3f 잠금화면 카드. 앱의 위젯 갤러리(DEBUG)에서도 그릴 수 있게 `ActivityViewContext`에 의존하지 않는다.
struct LiveActivityCard: View {
    let state: RestActivityAttributes.ContentState
    var isStale = false

    private var snapshot: TimerSnapshot { state.snapshot }
    private var display: RestDisplay { RestDisplay.from(snapshot, at: .now, isStale: isStale) }
    var isEnded: Bool { display.isEnded }
    var backgroundColor: Color { isEnded ? Color.brand.opacity(0.95) : Color(white: 0.08).opacity(0.85) }

    var body: some View {
        HStack(spacing: 12) {
            BigNumberLabel(display: display, referenceDate: .now, size: 54, onOrange: isEnded)
                .frame(minWidth: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(phaseTitle(display, snapshot: snapshot))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                WidgetSetDots(dots: snapshot.dots, size: 7, onOrange: isEnded)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            LiveActivityButtons(display: display, onOrange: isEnded, height: 34)
                .frame(width: 144)
        }
        .foregroundStyle(isEnded ? Color.black : Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// 3f/3g 버튼 묶음. 실행 중: [❙❙ / +10 / +30] + 건너뛰기. 대기·휴식 끝: 시작 CTA + 앱 열기. 완료: 한 번 더 + 앱 열기.
/// "종료"는 두지 않는다 — 카드가 작아 실수로 누르기 쉽다(2026-09-19). 끝내기는 앱 안 확인창으로.
struct LiveActivityButtons: View {
    let display: RestDisplay
    var onOrange = false
    var height: CGFloat = 36

    var body: some View {
        VStack(spacing: 8) {
            switch display {
            case .running, .paused:
                HStack(spacing: 6) {  // 3f: [❙❙] [+10] [+30]
                    IntentPill(isPaused ? "▶" : "❙❙", intent: TogglePauseIntent(), onOrange: onOrange, height: height)
                    IntentPill("+10", intent: AddSecondsIntent(seconds: 10), onOrange: onOrange, height: height)
                    IntentPill("+30", intent: AddSecondsIntent(seconds: 30), onOrange: onOrange, height: height)
                }
                IntentPill(String(localized: "Skip"), intent: SkipRestIntent(), prominent: true, onOrange: onOrange, height: height)
            case .finished:
                IntentPill(String(localized: "Go again"), intent: StartOverIntent(), prominent: true, onOrange: onOrange, height: height)
                LinkPill(String(localized: "Open app"), url: URL(string: "nextset://open")!, onOrange: onOrange, height: height)  // "종료"는 작은 카드에서 실수하기 쉬워 앱 안(확인창)에서만
            case .ended:
                IntentPill(String(localized: "Start rest"), intent: StartRestIntent(seconds: nil), prominent: true, onOrange: onOrange, height: height)
                LinkPill(String(localized: "Open app"), url: URL(string: "nextset://open")!, onOrange: onOrange, height: height)  // "종료"는 작은 카드에서 실수하기 쉬워 앱 안(확인창)에서만
            case .idle:
                IntentPill(String(localized: "Start"), intent: StartRestIntent(seconds: nil), prominent: true, onOrange: onOrange, height: height)
                LinkPill(String(localized: "Open app"), url: URL(string: "nextset://open")!, onOrange: onOrange, height: height)  // "종료"는 작은 카드에서 실수하기 쉬워 앱 안(확인창)에서만
            }
        }
    }

    private var isPaused: Bool { if case .paused = display { return true } else { return false } }
}

/// Dynamic Island 축소·최소 상태의 숫자.
private struct CompactTimerLabel: View {
    let display: RestDisplay
    var minimal = false

    var body: some View {
        Group {
            switch display {
            case .running(let end):
                Text(timerInterval: Date.now...max(end, .now), countsDown: true, showsHours: false)
                    .multilineTextAlignment(.trailing)
                    .frame(width: minimal ? 36 : 44)
            case .paused(let remaining): Text(formatRemaining(remaining))
            case .ended(let nextSet): Text(minimal ? "\(nextSet)" : String(localized: "Set \(nextSet)"))
            case .idle(let seconds): Text("\(seconds)")
            case .finished: Text("✓")
            }
        }
        .font(.system(size: minimal ? 13 : 15, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Color.brand)
    }
}
