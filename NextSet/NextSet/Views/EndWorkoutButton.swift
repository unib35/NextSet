import SwiftUI

private struct RequestWorkoutEndKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// 확인창을 거쳐 끝낸다. 길게 누르기가 어려운 VoiceOver 사용자의 경로.
    var requestWorkoutEnd: () -> Void {
        get { self[RequestWorkoutEndKey.self] }
        set { self[RequestWorkoutEndKey.self] = newValue }
    }
}

/// 좌상단 "종료" — 약 0.7초 길게 누르면 빨간색이 차오르며 끝난다. 짧게 누르면 "길게 누르기"로 안내한다.
/// 길게 누르기 자체가 실수 방지라 확인창은 띄우지 않는다(2026-10 시안). 휴식 중(3b·4a)과 세트가 있는 대기(3a)에만 둔다.
struct EndWorkoutButton: View {
    static let holdDuration: TimeInterval = 0.7

    @Environment(RestTimer.self) private var timer
    @Environment(\.requestWorkoutEnd) private var requestEnd
    @State private var isHolding = false
    @State private var showsHoldHint = false
    @State private var pressedAt: Date?
    @State private var hintTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isHolding ? Color.white : Color.danger)
            Text(showsHoldHint ? String(localized: "Hold to end") : String(localized: "End"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(height: 44)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                Color.danger.frame(width: isHolding ? proxy.size.width : 0)
            }
        }
        .background(Color.card)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.holdDuration) {
            isHolding = false
            pressedAt = nil
            timer.endWorkout()
        } onPressingChanged: { pressing in
            if pressing {
                pressedAt = .now
                hintTask?.cancel()
                showsHoldHint = false
                withAnimation(.linear(duration: Self.holdDuration)) { isHolding = true }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { isHolding = false }
                // 끝까지 누른 경우는 perform 에서 pressedAt 을 비운다 — 짧게 뗀 경우만 안내한다.
                if let pressedAt, Date.now.timeIntervalSince(pressedAt) < 0.3 { flashHoldHint() }
                self.pressedAt = nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timer.settings.mode == .single ? String(localized: "End timer") : String(localized: "End workout"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { requestEnd() }
    }

    private func flashHoldHint() {
        showsHoldHint = true
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showsHoldHint = false
        }
    }
}
