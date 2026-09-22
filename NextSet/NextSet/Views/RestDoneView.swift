import SwiftUI

/// 3c — 휴식 끝. 세트 모드는 탭할 때까지 유지(세트를 하는 동안 떠 있다). 카운트다운 모드(✓)만 잠시 후 대기로 돌아간다.
struct RestDoneView: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        let isSingle = timer.settings.mode == .single

        AdaptiveTimerScreen {
            VStack(spacing: 0) {
                HStack {
                    Text(isSingle ? String(localized: "Countdown complete") : String(localized: "Rest over"))
                    Spacer()
                    Text(timer.setCaption)
                        .opacity(0.6)
                }
                .font(.subheadline.weight(.semibold))
                SetDots(dots: timer.dots, onOrange: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)

            }
        } display: { numberSize in
            VStack(spacing: 0) {
                Text(isSingle ? "TIME UP" : "NEXT SET")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .opacity(0.6)
                BigNumber(text: isSingle ? "✓" : "\(timer.nextSetNumber)", size: numberSize, tracking: -numberSize * 0.05)
                    .padding(.top, 8)
                Text(isSingle ? String(localized: "Time is up") : String(localized: "Start set \(timer.nextSetNumber)"))
                    .font(.title2.weight(.semibold))
                    .padding(.top, 16)
                Text(
                    isSingle
                        ? String(localized: "Returning to the timer shortly.")
                        : String(localized: "When your set is done, tap to start your next rest.")
                )
                .font(.subheadline)
                .opacity(0.6)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 260)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } controls: {
            VStack(spacing: 6) {
                Button(action: timer.start) {
                    PillLabel(
                        title: isSingle ? String(localized: "Restart") : String(localized: "Start rest now"), fill: .black,
                        foreground: .brand)
                }
                if !isSingle {
                    // 휴식 시간을 바꾸려면 대기 화면(3a)으로. 시안 3c 에는 없는 보조 동작.
                    Button(action: timer.goToSetup) {
                        Text(String(localized: "Change time"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.black.opacity(0.7))
                }
                EndWorkoutButton(onOrange: true)
            }
            .buttonStyle(.pressable)
        }
        .foregroundStyle(.black)
        .background(Color.brand.ignoresSafeArea())
    }
}
