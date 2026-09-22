import SwiftUI

// 색은 `Shared/Theme.swift` (앱·위젯·워치 공통).

extension View {
    func screenPadding() -> some View {
        padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

/// 기기 이름/방향 대신 현재 창의 safe-area 내부 크기로 배치한다.
/// 같은 세 자식 뷰의 위치만 바꾸므로 크기 변경 중에도 뷰 identity를 유지한다.
struct AdaptiveTimerScreen<Header: View, Display: View, Controls: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var header: () -> Header
    @ViewBuilder var display: (CGFloat) -> Display
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 1040) - 48
            let sideBySide = !typeSize.isAccessibilitySize && width >= 560
            let numberSize = min(220, max(72, geometry.size.height * (sideBySide ? 0.38 : 0.28)))
            ScrollView {
                TimerPanelLayout(sideBySide: sideBySide, minimumHeight: max(0, geometry.size.height - 12)) {
                    header()
                    display(numberSize)
                    controls()
                }
                .frame(maxWidth: 992)
                .screenPadding()
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// 숫자 영역은 남은 높이를 사용하고, 부족하면 ScrollView의 콘텐츠 높이를 늘린다.
private struct TimerPanelLayout: Layout {
    var sideBySide: Bool
    var minimumHeight: CGFloat
    private let gap: CGFloat = 20

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? 320)
        let header = subviews[0].sizeThatFits(.init(width: width, height: nil))
        let panelWidth = sideBySide ? max(0, (width - gap) / 2) : width
        let display = subviews[1].sizeThatFits(.init(width: panelWidth, height: nil))
        let controls = subviews[2].sizeThatFits(.init(width: panelWidth, height: nil))
        let panelsHeight = sideBySide ? max(display.height, controls.height) : display.height + gap + controls.height
        return CGSize(width: width, height: max(minimumHeight, header.height + gap + panelsHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let header = subviews[0].sizeThatFits(.init(width: bounds.width, height: nil))
        subviews[0].place(
            at: bounds.origin, anchor: .topLeading,
            proposal: .init(width: bounds.width, height: header.height))
        let top = bounds.minY + header.height + gap
        let height = max(0, bounds.maxY - top)
        if sideBySide {
            let width = max(0, (bounds.width - gap) / 2)
            for index in 1...2 {
                let size = subviews[index].sizeThatFits(.init(width: width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(index - 1) * (width + gap), y: top + height / 2),
                    anchor: .leading, proposal: .init(width: width, height: size.height))
            }
        } else {
            let controls = subviews[2].sizeThatFits(.init(width: bounds.width, height: nil))
            let displayHeight = max(0, height - gap - controls.height)
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: top), anchor: .topLeading,
                proposal: .init(width: bounds.width, height: displayHeight))
            subviews[2].place(
                at: CGPoint(x: bounds.minX, y: bounds.maxY - controls.height), anchor: .topLeading,
                proposal: .init(width: bounds.width, height: controls.height))
        }
    }
}
