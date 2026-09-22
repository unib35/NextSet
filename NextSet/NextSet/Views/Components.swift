import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// 빅 넘버. 디자인의 line-height .9 에 맞춰 위아래 여백을 줄인다.
struct BigNumber: View {
    let text: String
    let size: CGFloat
    let tracking: CGFloat

    var body: some View {
        Text(trackedText)
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.vertical, -size * 0.14)
    }

    /// 마지막 글자에는 자간을 주지 않는다 — 음수 자간이 끝 글자를 잘라먹지 않도록.
    private var trackedText: AttributedString {
        var string = AttributedString(text)
        if let last = string.characters.indices.last {
            string[string.startIndex..<last].tracking = tracking
        }
        return string
    }
}

struct SetDots: View {
    let dots: [SetDot]
    var size: CGFloat = 8
    var onOrange = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(dots.indices, id: \.self) { index in
                Circle()
                    .fill(color(for: dots[index]))
                    .frame(width: size, height: size)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: dots)
    }

    private func color(for dot: SetDot) -> Color {
        switch dot {
        case .past: onOrange ? .black : .brand
        case .current: onOrange ? .black.opacity(0.45) : .white
        case .upcoming: onOrange ? .black.opacity(0.15) : .white.opacity(0.2)
        }
    }
}

struct PillLabel: View {
    let title: String
    let fill: Color
    let foreground: Color
    var height: CGFloat = 60
    var fontSize: CGFloat = 18
    var weight: Font.Weight = .bold

    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: weight))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
    }
}

struct CircleIcon: View {
    let systemName: String
    let fill: Color
    let foreground: Color
    var diameter: CGFloat = 60

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: diameter, height: diameter)
            .background(fill, in: Circle())
            .contentShape(Circle())
    }
}

struct ProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.surface)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
        }
        .frame(height: 3)
        .clipShape(Capsule())
        .animation(.linear(duration: 0.1), value: progress)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.cardRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// flex 비율로 폭을 나누는 가로 스택. `layoutWeight`가 없는 자식은 고유 폭을 쓴다.
struct WeightedHStack: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.replacingUnspecifiedDimensions().width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let fixedWidth = subviews
            .filter { $0[LayoutWeight.self] == 0 }
            .map { $0.sizeThatFits(.unspecified).width }
            .reduce(0, +)
        let totalWeight = subviews.map { $0[LayoutWeight.self] }.reduce(0, +)
        let flexibleWidth = max(0, bounds.width - fixedWidth - spacing * CGFloat(subviews.count - 1))

        var x = bounds.minX
        for subview in subviews {
            let weight = subview[LayoutWeight.self]
            let width = weight > 0 && totalWeight > 0
                ? flexibleWidth * weight / totalWeight
                : subview.sizeThatFits(.unspecified).width
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

private nonisolated struct LayoutWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 0
}

extension View {
    func layoutWeight(_ weight: CGFloat) -> some View {
        layoutValue(key: LayoutWeight.self, value: weight)
    }
}


/// 3b 의 [−10 | +10 | +30] — 알약 하나를 세 칸으로 나눈 버튼. 칸 사이 1px 구분선.
struct SegmentedPill: View {
    struct Segment {
        let title: String
        var accessibility: String? = nil
        var dimmed = false
        let action: () -> Void

        init(title: String, accessibility: String? = nil, dimmed: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.accessibility = accessibility
            self.dimmed = dimmed
            self.action = action
        }
    }

    let segments: [Segment]
    var height: CGFloat = 60

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Button(action: segment.action) {
                    Text(segment.title)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(segment.dimmed ? 0.6 : 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(segment.accessibility ?? segment.title)
                if index < segments.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, 14)
                }
            }
        }
        .frame(height: height)
        .background(Color.surface, in: Capsule())
        .clipShape(Capsule())
    }
}
