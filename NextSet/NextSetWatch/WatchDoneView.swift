import SwiftUI

/// 4f 휴식 끝(오렌지) / 운동 완료 — 손목 햅틱은 `RestFeedback`이 낸다. 탭하면 다음 휴식.
struct WatchDoneView: View {
    @Environment(RestTimer.self) private var timer

    private var isFinished: Bool { timer.session.phase == .finished }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WatchCaptionRow(caption: timer.setCaption, onOrange: true) { WatchSetDots(dots: timer.dots, onOrange: true) }
            Spacer(minLength: 2)
            VStack(spacing: 0) {
                // 4f: 한국어 라벨(2026-10 시안), 큰 숫자와 겹치지 않게 띄운다.
                Text(isFinished ? String(localized: "All done") : String(localized: "Next set"))
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.7)
                WatchBigNumber(text: isFinished ? "✓" : "\(timer.nextSetNumber)", color: .black)
                    .padding(.top, 8)
            }
            Spacer(minLength: 2)
            HStack(spacing: 6) {
                if !isFinished {
                    // 휴식 시간을 바꾸려면 대기(4d)로 — 휴식 끝 화면은 탭할 때까지 유지되므로 출구가 필요하다
                    Button { timer.goToSetup() } label: {
                        Text(String(localized: "Time"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .frame(width: 56)  // 고정 폭. layoutPriority 로 나누면 이 버튼이 사라진다(위젯에서 겪음)
                            .frame(height: WatchMetrics.pillHeight)
                            .background(Color.black.opacity(0.14), in: Capsule())
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Change time"))
                }
                Button {
                    if isFinished { timer.startOver() } else { timer.start() }
                } label: {
                    Text(isFinished ? String(localized: "Go again") : String(localized: "Start rest"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: WatchMetrics.pillHeight)
                        .background(Color.black, in: Capsule())
                        .foregroundStyle(Color.brand)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, WatchMetrics.horizontalPadding)
        .padding(.bottom, WatchMetrics.bottomPadding)
        .ignoresSafeArea(.container, edges: .bottom)  // 버튼을 화면 맨 아래까지 내려 숫자 주변을 넓게 쓴다
        .foregroundStyle(.black)
        .background(Color.brand.ignoresSafeArea())
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
