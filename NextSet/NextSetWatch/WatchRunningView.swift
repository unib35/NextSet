import SwiftUI

/// 4e 휴식 중 — 숫자 탭 = 일시정지/재개, 숫자 길게 누름 또는 ✕ = 종료 메뉴, Crown = ±10초, 마지막 3초는 흰색.
/// 하단: ✕ · +10 · 건너뛰기.
struct WatchRunningView: View {
    @Environment(RestTimer.self) private var timer
    @State private var showsMenu = false
    @State private var crown: Double = 0
    @State private var crownApplied: Double = 0

    private static let crownStep = 10  // 시안: Crown 한 눈금 = ±10초

    private var isPaused: Bool { timer.session.phase == .paused }
    private var numberColor: Color {
        if timer.isFinalCountdown { return .white }
        return isPaused ? Color.brand.opacity(0.45) : .brand
    }

    /// 종료 메뉴 제목 (시안 wmTitle): "N세트 · 휴식 합계", 세트가 없으면 "휴식 중".
    private var menuTitle: String {
        let sets = timer.session.completedSets
        guard sets > 0 else { return String(localized: "Resting") }
        let rested = timer.session.totalRested + (timer.session.restDuration - timer.remaining)
        return String(localized: "\(sets) sets · Rest \(RestTimer.format(rested))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WatchCaptionRow(caption: timer.setCaption) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.card)
                        Capsule().fill(numberColor)
                            .frame(width: proxy.size.width * timer.progress)
                    }
                }
                .frame(height: 3)
            }
            Spacer(minLength: 2)
            WatchBigNumber(text: "\(timer.displaySeconds)", color: numberColor,
                           scale: timer.isFinalCountdown ? 1.1 : 1)
                .contentShape(Rectangle())
                .onTapGesture { timer.togglePause() }
                .onLongPressGesture { showsMenu = true }
                .accessibilityIdentifier("timer.number")
                .accessibilityLabel(isPaused ? String(localized: "Resume") : String(localized: "Pause"))
                .accessibilityAddTraits(.isButton)
                .animation(.easeInOut(duration: 0.2), value: timer.isFinalCountdown)
            Spacer(minLength: 2)
            HStack(spacing: 6) {
                Button { showsMenu = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.danger)
                        .frame(width: WatchMetrics.pillHeight, height: WatchMetrics.pillHeight)
                        .background(Color.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "End menu"))
                WatchPill(label: "+\(Self.crownStep)") { timer.adjustRemaining(by: Self.crownStep) }
                WatchPill(label: String(localized: "Skip"), prominent: true) { timer.skip() }
            }
        }
        .padding(.horizontal, WatchMetrics.horizontalPadding)
        .padding(.bottom, WatchMetrics.bottomPadding)
        .ignoresSafeArea(.container, edges: .bottom)  // 버튼을 화면 맨 아래까지 내려 숫자 주변을 넓게 쓴다
        .focusable()
        .digitalCrownRotation($crown, from: -10_000, through: 10_000, by: 1, sensitivity: .medium,
                              isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            let detents = Int((value - crownApplied).rounded(.towardZero))
            guard detents != 0 else { return }
            crownApplied += Double(detents)
            timer.adjustRemaining(by: detents * Self.crownStep)
        }
        .confirmationDialog(menuTitle, isPresented: $showsMenu, titleVisibility: .visible) {
            Button(String(localized: "End workout"), role: .destructive) { timer.endWorkout() }
            Button(String(localized: "Restart this rest")) { timer.restartRest() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
    }
}
