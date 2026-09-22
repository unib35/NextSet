import AppIntents
import SwiftUI
import WidgetKit

/// 큰 숫자 한 자리. 실행 중이면 시스템이 매초 그려 주는 카운트다운(`Text(timerInterval:)`).
struct BigNumberLabel: View {
    let display: RestDisplay
    let referenceDate: Date
    var size: CGFloat = 40
    var onOrange = false
    var monochrome = false  // 잠금화면처럼 색을 못 쓰는 곳

    var body: some View {
        Group {
            switch display {
            case .idle(let seconds): Text("\(seconds)")
            case .running(let end):
                Text(timerInterval: referenceDate...max(end, referenceDate), countsDown: true, showsHours: false)
                    .multilineTextAlignment(.leading)
            case .paused(let remaining): Text(formatRemaining(remaining))
            case .ended(let nextSet): Text("\(nextSet)")
            case .finished: Text("✓")
            }
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .tracking(-size * 0.04)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(monochrome ? Color.primary : onOrange ? Color.black : Color.brand)
    }
}

/// 앱의 `SetDots`와 같은 뜻. `monochrome`이면(잠금화면) 밝기로만 구분한다.
struct WidgetSetDots: View {
    let dots: [SetDot]
    var size: CGFloat = 6
    var onOrange = false
    var monochrome = false

    var body: some View {
        HStack(spacing: size * 0.6) {
            ForEach(dots.indices, id: \.self) { index in
                Circle()
                    .fill(color(dots[index]))
                    .frame(width: size, height: size)
            }
        }
    }

    private func color(_ dot: SetDot) -> Color {
        if monochrome {
            switch dot {
            case .past: return .primary
            case .current: return .primary.opacity(0.55)
            case .upcoming: return .primary.opacity(0.2)
            }
        }
        switch dot {
        case .past: return onOrange ? .black : .brand
        case .current: return onOrange ? .black.opacity(0.45) : .white
        case .upcoming: return onOrange ? .black.opacity(0.15) : .white.opacity(0.2)
        }
    }
}

/// 위젯·Live Activity 의 알약 버튼. 눌러도 앱이 열리지 않고 인텐트가 앱 프로세스에서 돈다.
struct IntentPill<Intent: AppIntent>: View {
    let label: String
    let intent: Intent
    var prominent = false
    var onOrange = false
    var height: CGFloat = 44
    var bold = false  // 프리셋 숫자(16/700)

    init(_ label: String, intent: Intent, prominent: Bool = false, onOrange: Bool = false, height: CGFloat = 44, bold: Bool = false) {
        self.label = label
        self.intent = intent
        self.prominent = prominent
        self.onOrange = onOrange
        self.height = height
        self.bold = bold
    }

    var body: some View {
        Button(intent: intent) {
            Text(label)
                .font(.system(size: height < 40 ? 13 : bold ? 16 : 15, weight: prominent || bold ? .bold : .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(background, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if prominent { return onOrange ? .black : .brand }
        return onOrange ? .black.opacity(0.14) : .white.opacity(0.12)
    }

    private var foreground: Color {
        if prominent { return onOrange ? .brand : .black }
        return onOrange ? .black : .white
    }
}

/// 딥링크로 앱을 여는 알약 (Live Activity 에서 "앱 열기"). 실수로 눌러도 되돌릴 수 있는 동작만 이걸로 둔다.
struct LinkPill: View {
    let label: String
    let url: URL
    var onOrange = false
    var height: CGFloat = 44

    init(_ label: String, url: URL, onOrange: Bool = false, height: CGFloat = 44) {
        self.label = label
        self.url = url
        self.onOrange = onOrange
        self.height = height
    }

    var body: some View {
        Link(destination: url) {
            Text(label)
                .font(.system(size: height < 40 ? 13 : 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(onOrange ? Color.black.opacity(0.14) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(onOrange ? Color.black : Color.white)
        }
    }
}
