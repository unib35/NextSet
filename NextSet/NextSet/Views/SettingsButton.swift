import SwiftUI

private struct RequestSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var requestSettings: () -> Void {
        get { self[RequestSettingsKey.self] }
        set { self[RequestSettingsKey.self] = newValue }
    }
}

/// 설정 시트를 여는 기어. 대기(3a)·휴식 중(3b)·휴식 끝(3c) 머리의 같은 자리(오른쪽 위)에 둔다.
/// 시트는 `ContentView`가 띄운다 — 휴식이 끝나 화면이 바뀌어도 열린 시트가 닫히지 않게.
struct SettingsButton: View {
    @Environment(\.requestSettings) private var requestSettings
    var onOrange = false

    var body: some View {
        HeaderIconButton(systemImage: "gearshape", label: String(localized: "Settings"), onOrange: onOrange, action: requestSettings)
    }
}

/// 머리 줄의 44pt 원형 선 아이콘 버튼(기어·최근 운동).
struct HeaderIconButton: View {
    let systemImage: String
    let label: String
    var onOrange = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(onOrange ? Color.black.opacity(0.75) : Color.white.opacity(0.75))
                .frame(width: 44, height: 44)
                .background(onOrange ? Color.black.opacity(0.12) : Color.card, in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}

/// 3a·3b·3c 공통 머리: [왼쪽] … [세트 캡션][기어], 그 아래 세트 점. 높이를 같게 둬서 화면이 바뀌어도 숫자가 움직이지 않는다.
struct TimerHeader<Leading: View, Trailing: View>: View {
    @Environment(RestTimer.self) private var timer
    var onOrange = false
    var showsCaption = true
    var showsSettings = true
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var dotsTrailing: () -> Trailing

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 12) {
                leading()
                Spacer(minLength: 8)
                if showsCaption {
                    Text(timer.setCaption)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .opacity(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                if showsSettings { SettingsButton(onOrange: onOrange) }
            }
            .frame(minHeight: 44)
            SetDots(dots: timer.dots, onOrange: onOrange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) { dotsTrailing() }
        }
    }
}

extension TimerHeader where Trailing == EmptyView {
    init(onOrange: Bool = false, showsCaption: Bool = true, showsSettings: Bool = true, @ViewBuilder leading: @escaping () -> Leading) {
        self.init(onOrange: onOrange, showsCaption: showsCaption, showsSettings: showsSettings, leading: leading, dotsTrailing: { EmptyView() })
    }
}
