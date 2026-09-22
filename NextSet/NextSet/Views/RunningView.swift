import SwiftUI

/// 3b 휴식 중 / 일시정지 (숫자 탭) + 4a 마지막 3초 햅틱 카운트.
struct RunningView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(FirstRunHints.self) private var hints

    var body: some View {
        let isPaused = timer.session.phase == .paused
        let isFinal = timer.isFinalCountdown
        let numberColor: Color = isPaused ? .white.opacity(0.35) : isFinal ? .white : .brand

        AdaptiveTimerScreen {
            VStack(spacing: 0) {
                HStack {
                    Text(
                        isPaused
                            ? String(localized: "Paused")
                            : timer.settings.mode == .single ? String(localized: "Countdown") : String(localized: "Rest"))
                    Spacer()
                    Text(timer.setCaption)
                        .opacity(0.5)
                }
                .font(.subheadline.weight(.semibold))
                SetDots(dots: timer.dots)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)

            }
        } display: { numberSize in
            Button(action: timer.togglePause) {
                VStack(spacing: 0) {
                    BigNumber(text: "\(timer.displaySeconds)", size: numberSize, tracking: -numberSize * 0.05)
                        .foregroundStyle(numberColor)
                        .scaleEffect(isFinal ? 1.08 : 1)
                    Group {
                        if isFinal {
                            CountdownTicks(step: timer.countdownStep)
                        } else {
                            Text(isPaused ? String(localized: "Tap to resume") : String(localized: "Tap to pause"))
                                .font(.subheadline)
                                .opacity(0.7)
                        }
                    }
                    .frame(height: 20)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timer.number")
            .accessibilityLabel(String(localized: "\(timer.displaySeconds) seconds remaining"))
            .accessibilityHint(isPaused ? String(localized: "Resume") : String(localized: "Pause"))

        } controls: {
            VStack(spacing: 0) {
                // 6c 첫 휴식 중 한 번: 잠금화면·Dynamic Island 힌트
                if hints.showsLockScreenHint(endedWorkouts: timer.endedWorkoutCount) {
                    HintCard(
                        systemImage: "iphone",
                        text: String(localized: "Keep track on your Lock Screen and Dynamic Island when you leave the app"),
                        dismissLabel: String(localized: "Got it")
                    ) { hints.markLockScreenSeen() }
                    .padding(.bottom, 16)
                    .onDisappear { hints.markLockScreenSeen() }  // 첫 휴식이 끝나면 다시 보여주지 않는다
                    .transition(.opacity)
                }

                NotificationStatusView()
                    .padding(.bottom, 12)

                ProgressBar(progress: timer.progress, color: numberColor)
                    .padding(.bottom, 20)

                WeightedHStack(spacing: 12) {
                    // 3b: [−10 | +10 | +30] 한 알약에 세 칸
                    SegmentedPill(segments: [
                        .init(title: "−10", accessibility: String(localized: "Subtract 10 seconds"), dimmed: true) {
                            timer.adjustRemaining(by: -10)
                        },
                        .init(title: "+10", accessibility: String(localized: "Add 10 seconds")) { timer.adjustRemaining(by: 10) },
                        .init(title: "+30", accessibility: String(localized: "Add 30 seconds")) { timer.adjustRemaining(by: 30) },
                    ])
                    .layoutWeight(2)
                    Button(action: timer.skip) {
                        PillLabel(title: String(localized: "Skip"), fill: .brand, foreground: .black)
                    }
                    .layoutWeight(1.4)
                }
                .buttonStyle(.pressable)
                EndWorkoutButton(onOrange: isFinal)
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
        .background((isFinal ? Color.finalCountdown : Color.black).ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: isFinal)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
    }
}

/// 4a 마지막 3초 — 점 세 개가 햅틱 박자에 맞춰 하나씩 켜진다. 글자("햅틱 1/3")는 뺐다(2026-09-18, 숫자만으로 충분).
private struct CountdownTicks: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index <= step ? Color.white : Color.white.opacity(0.18))
                    .frame(width: 10, height: 10)
                    .scaleEffect(index == step ? 1.5 : 1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: step)
        .accessibilityHidden(true)
    }
}
