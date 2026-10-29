import SwiftUI

/// 3c — 휴식 끝("NEXT SET" 머리글은 2026-10 시안에서 뺐다). 세트 모드는 탭할 때까지 유지(세트를 하는 동안 떠 있다). 카운트다운 모드(✓)만 잠시 후 대기로 돌아간다.
struct RestDoneView: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        let isSingle = timer.settings.mode == .single

        AdaptiveTimerScreen {
            // 시안 3c에는 종료·기어가 없다. 앱은 탭할 때까지 이 화면에 머무르므로 기어는 남기고(T-83), 종료는 "시간 바꾸기" → 3a에서.
            TimerHeader(onOrange: true) {
                Text(isSingle ? String(localized: "Countdown complete") : String(localized: "Rest over"))
                    .font(.system(size: 15, weight: .semibold))
            }
        } display: { numberSize in
            VStack(spacing: 0) {
                BigNumber(text: isSingle ? "✓" : "\(timer.nextSetNumber)", size: numberSize, tracking: -numberSize * 9 / 168)
                    .frame(height: numberSize * 152 / 168)
                Text(isSingle ? String(localized: "Time is up") : String(localized: "Start set \(timer.nextSetNumber)"))
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 16)
                Text(
                    isSingle
                        ? String(localized: "Returning to the timer shortly.")
                        : String(localized: "When your set is done, tap to start your next rest.")
                )
                .font(.system(size: 15))
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
            }
            .buttonStyle(.pressable)
        }
        .foregroundStyle(.black)
        .background(Color.brand.ignoresSafeArea())
    }
}
