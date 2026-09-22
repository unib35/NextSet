import SwiftUI

/// 3a 기어 → 설정 시트 (4c의 알림·타이머 항목).
struct SettingsSheet: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = timer

        NavigationStack {
            ScrollView {
                content
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .widgetTap: OptionList(title: String(localized: "Widget tap action"), selection: $model.settings.widgetTap)
                case .liveActivity: LiveActivityToggle(isOn: $model.settings.liveActivity)
                case .widgetGuide: WidgetGuideView(presentation: .pushed)
                case .privacy: PrivacyPolicyView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Color.brand)
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.sheet)
        .presentationCornerRadius(38)
    }

    enum Destination: Hashable { case widgetTap, liveActivity, widgetGuide, privacy }

    private var content: some View {
        @Bindable var model = timer

        return VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(localized: "Settings"))
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                    Spacer()
                    Button(String(localized: "Done")) { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }

                SectionTitle(title: String(localized: "Rest alerts"))
                SettingsGroup {
                    SettingsRow(title: String(localized: "Sound"), subtitle: String(localized: "Soft beeps at 3·2·1, then a bell")) {
                        SegmentedPicker(selection: $model.settings.sound)
                    }
                    SettingsRow(title: String(localized: "Haptics")) {
                        SegmentedPicker(selection: $model.settings.haptic)
                    }
                    SettingsRow(title: String(localized: "Final 3 seconds"), subtitle: String(localized: "Sound, haptics and visual countdown")) {
                        Toggle(String(localized: "Final 3 seconds"), isOn: $model.settings.countdownHaptics)
                            .labelsHidden()
                    }
                    SettingsRow(title: String(localized: "Repeat alerts"), subtitle: String(localized: "Every 30s, up to 4 times if another set remains"), showsDivider: false) {
                        Toggle(String(localized: "Repeat alerts"), isOn: $model.settings.repeatAlert)
                            .labelsHidden()
                    }
                }

                NotificationStatusView(showsReadyState: true)
                    .padding(.top, 16)

                SectionTitle(title: String(localized: "Timer"))
                SettingsGroup {
                    SettingsRow(title: String(localized: "Default rest")) {
                        ValueStepper(value: String(localized: "\(timer.settings.restSeconds)s"),
                                     label: String(localized: "Default rest"),
                                     decrement: { timer.adjustRestSeconds(by: -5) },
                                     increment: { timer.adjustRestSeconds(by: 5) })
                    }
                    SettingsRow(title: String(localized: "Set goal"), subtitle: String(localized: "Unlimited until you end the workout"), showsDivider: false) {
                        ValueStepper(value: timer.goalLabel,
                                     label: String(localized: "Set goal"),
                                     decrement: { timer.adjustGoal(by: -1) },
                                     increment: { timer.adjustGoal(by: 1) })
                    }
                }

                SectionTitle(title: String(localized: "Lock Screen"))
                SettingsGroup {
                    NavigationLink(value: Destination.widgetTap) {
                        SettingsRow(title: String(localized: "Widget tap action")) {
                            DisclosureValue(text: timer.settings.widgetTap.label)
                        }
                    }
                    NavigationLink(value: Destination.liveActivity) {
                        SettingsRow(title: "Live Activity") {
                            DisclosureValue(text: timer.settings.liveActivity ? String(localized: "On") : String(localized: "Off"))
                        }
                    }
                    NavigationLink(value: Destination.widgetGuide) {
                        SettingsRow(title: String(localized: "How to add widgets"), showsDivider: false) {
                            DisclosureValue(text: "")
                        }
                    }
                }
                SectionTitle(title: String(localized: "About"))
                SettingsGroup {
                    NavigationLink(value: Destination.privacy) {
                        SettingsRow(title: String(localized: "Privacy Policy"), showsDivider: false) {
                            DisclosureValue(text: "")
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 40)
    }
}

/// 시안 4c 의 "즉시 시작 ›" — 오른쪽 값 + 꺾쇠.
private struct DisclosureValue: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            if !text.isEmpty { Text(text) }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
        }
        .font(.system(size: 17))
        .foregroundStyle(.white.opacity(0.5))
    }
}

/// 옵션 하나를 고르는 하위 화면.
private struct OptionList<Option: LabeledOption>: View where Option.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: Option
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SubHeader(title: title)
                SettingsGroup {
                    ForEach(Array(Option.allCases.enumerated()), id: \.element) { index, option in
                        Button {
                            selection = option
                        } label: {
                            SettingsRow(title: option.label, showsDivider: index < Option.allCases.count - 1) {
                                if option == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.brand)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
        }
        .toolbar(.hidden, for: .navigationBar)  // 커스텀 ‹ 머리를 쓰므로 iOS 기본 뒤로가기는 숨긴다
        .navigationBarBackButtonHidden(true)
    }
}

private struct LiveActivityToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SubHeader(title: "Live Activity")
                SettingsGroup {
                    SettingsRow(title: String(localized: "Lock Screen · Dynamic Island"), subtitle: String(localized: "Show time remaining and controls during rest"), showsDivider: false) {
                        Toggle("Live Activity", isOn: $isOn).labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
        }
        .toolbar(.hidden, for: .navigationBar)  // 커스텀 ‹ 머리를 쓰므로 iOS 기본 뒤로가기는 숨긴다
        .navigationBarBackButtonHidden(true)
    }
}

/// 하위 화면 머리: ‹ 뒤로 + 제목.
private struct SubHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Back"))
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.5)
        }
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.4))
            .padding(.top, 28)
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 16)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, 10)
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var showsDivider = true
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .opacity(0.5)
                }
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            }
        }
    }
}

struct SegmentedPicker<Option: LabeledOption>: View where Option.AllCases: RandomAccessCollection {
    @Binding var selection: Option
    var fullWidth = false  // 6d 처럼 칸을 같은 폭으로 늘릴 때

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Option.allCases, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .frame(maxWidth: fullWidth ? .infinity : nil)
                        .frame(height: fullWidth ? 32 : 28)
                        .background(isSelected ? Color.brand : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.cardRaised, in: RoundedRectangle(cornerRadius: 9))
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}

private struct ValueStepper: View {
    let value: String
    let label: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            stepButton("minus", label: String(localized: "Decrease \(label)"), action: decrement)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.brand)
                .frame(minWidth: 56)
            stepButton("plus", label: String(localized: "Increase \(label)"), action: increment)
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}
