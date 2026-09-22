import SwiftUI

/// 6d 위젯 추가하는 방법. 설정 › 잠금화면 › "위젯 추가하는 방법", 또는 두 번째 운동 종료 후 힌트에서 진입.
struct WidgetGuideView: View {
    enum Presentation { case pushed, sheet }
    var presentation: Presentation = .pushed
    @Environment(\.dismiss) private var dismiss
    @State private var tab: WidgetGuideTab = .lock

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if presentation == .pushed {
                        Button { dismiss() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                                Text(String(localized: "Settings"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.brand)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Back"))
                    }
                    Spacer()
                    if presentation == .sheet {
                        Button(String(localized: "Done")) { dismiss() }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.brand)
                    }
                }
                Text(String(localized: "Add widgets"))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .padding(.top, presentation == .pushed ? 18 : 6)
                Text(String(localized: "Add NextSet to the screens you use most.\nStart rest and check the time remaining at a glance."))
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 8)

                SegmentedPicker(selection: $tab, fullWidth: true)
                    .padding(.top, 22)

                WidgetGuideIllustration(tab: tab)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)

                VStack(spacing: 0) {
                    ForEach(Array(tab.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Color.brand, in: Circle())
                            Text(step)
                                .font(.system(size: 15))
                                .lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.top, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if index < tab.steps.count - 1 {
                                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 22)

                Text(tab.footer)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, presentation == .sheet ? 26 : 12)
            .padding(.bottom, 40)
        }
        .foregroundStyle(.white)
        .background(Color.sheet)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.sheet)
        .presentationCornerRadius(38)
    }


}

enum WidgetGuideTab: CaseIterable, LabeledOption {
    case lock, home, controlCenter

    var label: String {
        switch self {
        case .lock: String(localized: "Lock Screen")
        case .home: String(localized: "Home Screen")
        case .controlCenter: String(localized: "Control Center")
        }
    }

    /// 그림에 강조한 위치는 각 안내의 2단계에 해당한다.
    var steps: [String] {
        switch self {
        case .lock: [String(localized: "Touch and hold the Lock Screen, then tap \"Customize\"."),
                     String(localized: "Choose \"Lock Screen\", then tap \"Add Widgets\" below the clock."),
                     String(localized: "Find \"NextSet\" in the list and tap the size you want."),
                     String(localized: "Close the widget list and tap \"Done\". Tapping the widget opens the app and starts rest.")]
        case .home: [String(localized: "Touch and hold an empty area on your Home Screen to enter edit mode."),
                     String(localized: "Tap \"Edit\" at the top left, then \"Add Widget\"."),
                     String(localized: "Search for \"NextSet\" and choose the small or medium widget."),
                     String(localized: "Tap \"Add Widget\", move it into place, then tap \"Done\".")]
        case .controlCenter: [String(localized: "Swipe down from the top-right corner to open Control Center."),
                              String(localized: "Tap + at the top left, then \"Add a Control\" at the bottom."),
                              String(localized: "Search for \"NextSet\" and tap the \"NextSet\" control."),
                              String(localized: "Drag the corner to resize it, then move it where you want.")]
        }
    }

    var footer: String {
        switch self {
        case .lock: String(localized: "During rest, the widget shows the time remaining.")
        case .home: String(localized: "The medium widget gives you three presets to start from.")
        case .controlCenter: String(localized: "You can also replace the flashlight or camera button on your Lock Screen with this control.")
        }
    }
}
