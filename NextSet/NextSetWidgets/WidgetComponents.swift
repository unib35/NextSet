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
        .widgetAccentable()  // 색조(B2): 숫자는 강조 그룹 — 오렌지가 사라져도 숫자가 먼저 읽힌다
    }
}

/// 앱의 `SetDots`와 같은 뜻. `monochrome`이면(잠금화면) 밝기로만 구분한다.
struct WidgetSetDots: View {
    let dots: SetProgress
    var size: CGFloat = 6
    var onOrange = false
    var monochrome = false

    var body: some View {
        // WidgetKit/Live Activity는 가로 스크롤을 지원하지 않으므로 긴 진행은 정확한 수로 표시한다.
        ViewThatFits(in: .horizontal) {
            if dots.count <= 20 {
                HStack(spacing: size * 0.6) {
                    ForEach(dots.indices, id: \.self) { index in
                        Circle()
                            .fill(color(dots[index]))
                            .frame(width: size, height: size)
                            .widgetAccentable(dots[index] == .past)
                    }
                }
                .fixedSize()
            }
            Text("\(dots.pastCount)/\(dots.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(color(.past))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
    @Environment(\.widgetRenderingMode) private var renderingMode
    let label: String
    var systemImage: String? = nil  // 있으면 글자 대신 선 아이콘, label 은 VoiceOver 이름
    let intent: Intent
    var prominent = false
    var onOrange = false
    var height: CGFloat = 44
    var bold = false  // 프리셋 숫자(16/700)

    init(_ label: String, systemImage: String? = nil, intent: Intent, prominent: Bool = false, onOrange: Bool = false, height: CGFloat = 44, bold: Bool = false) {
        self.label = label
        self.systemImage = systemImage
        self.intent = intent
        self.prominent = prominent
        self.onOrange = onOrange
        self.height = height
        self.bold = bold
    }

    var body: some View {
        Button(intent: intent) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage).accessibilityLabel(label)
                } else {
                    Text(label)
                }
            }
                .font(.system(size: height < 40 ? 13 : bold ? 16 : 15, weight: prominent || bold ? .bold : .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(background, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(foreground)
                // 색조(B2): 선택된 프리셋·주 버튼만 강조색. 이 모드에선 강조 그룹 밖이 한 색이라 "칠한 배경 + 어두운 글자"를 못 쓰므로 글자를 강조색으로.
                .widgetAccentable(prominent && renderingMode == .accented)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if renderingMode == .accented { return .white.opacity(prominent ? 0.2 : 0.12) }
        if prominent { return onOrange ? .black : .brand }
        return onOrange ? .black.opacity(0.14) : .white.opacity(0.12)
    }

    private var foreground: Color {
        if renderingMode == .accented { return .white }
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
