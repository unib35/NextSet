import SwiftUI

/// 4d 대기 — Digital Crown 으로 시간 조절, 숫자 탭으로 시작.
struct WatchSetupView: View {
    @Environment(RestTimer.self) private var timer
    @State private var crown: Double = 60
    @State private var crownReady = false  // digitalCrownRotation 이 초기값을 건드리는 동안은 설정에 반영하지 않는다
    @State private var confirmsEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WatchCaptionRow(caption: timer.setCaption) { WatchSetDots(dots: timer.dots) }
            Spacer(minLength: 2)
            VStack(spacing: 6) {  // 시안 4d: 숫자 아래 6px 에 "초 · 탭하여 시작"
                WatchBigNumber(text: "\(timer.settings.restSeconds)")
                Text(String(localized: "sec · tap to start"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture { timer.start() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Start \(timer.settings.restSeconds)s rest"))
            .accessibilityAddTraits(.isButton)
            Spacer(minLength: 2)
            HStack(spacing: 6) {
                if timer.canEndWorkout {
                    Button { confirmsEnd = true } label: {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                            .foregroundStyle(Color.danger)
                            .frame(width: WatchMetrics.pillHeight, height: WatchMetrics.pillHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "End workout"))
                }
                WatchPill(label: "−") { timer.adjustRestSeconds(by: -5) }
                WatchPill(label: "+") { timer.adjustRestSeconds(by: 5) }
            }
        }
        .padding(.horizontal, WatchMetrics.horizontalPadding)
        .padding(.bottom, WatchMetrics.bottomPadding)
        .ignoresSafeArea(.container, edges: .bottom)  // 버튼을 화면 맨 아래까지 내려 숫자 주변을 넓게 쓴다
        .focusable()
        .confirmationDialog(String(localized: "End this workout?"), isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button(String(localized: "Save and end"), role: .destructive) { timer.endWorkout() }
            Button(String(localized: "Keep going"), role: .cancel) {}
        }
        .digitalCrownRotation($crown, from: Double(TimerSettings.restRange.lowerBound),
                              through: Double(TimerSettings.restRange.upperBound), by: 5,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear {
            crown = Double(timer.settings.restSeconds)
            Task { @MainActor in crownReady = true }  // 첫 레이아웃이 끝난 뒤부터
        }
        .onChange(of: crown) { _, value in
            guard crownReady else { return }
            let seconds = Int((value / 5).rounded()) * 5
            if seconds != timer.settings.restSeconds { timer.setRestSeconds(seconds) }
        }
        .onChange(of: timer.settings.restSeconds) { _, seconds in
            if Int(crown) != seconds { crown = Double(seconds) }
        }
    }
}
