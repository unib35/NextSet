import SwiftUI

/// 기어(`SettingsButton`) → 설정 시트. 처음엔 자주 바꾸는 세 가지(기본 휴식·소리·햅틱)와 "모든 설정 ›"만 보이는 낮은 시트,
/// "모든 설정"을 누르면 4c 전체 설정으로 넘어가며 시트가 커진다(2026-10 시안). 휴식 중·휴식 끝 화면에서도 열린다.
struct SettingsSheet: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Destination] = []
    @State private var compactHeight: CGFloat = 400
    @State private var detent: PresentationDetent = .height(400)

    var body: some View {
        @Bindable var model = timer

        NavigationStack(path: $path) {
            ScrollView {
                quick
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        let fitted = min(height, 640)
                        guard abs(fitted - compactHeight) > 1 else { return }
                        let wasCompact = detent == .height(compactHeight)
                        compactHeight = fitted
                        if wasCompact { detent = .height(fitted) }
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .all: AllSettingsView(close: { dismiss() })
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
        .presentationDetents([.height(compactHeight), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.sheet)
        .presentationCornerRadius(38)
        .onChange(of: path) { _, path in
            withAnimation(.smooth) { detent = path.isEmpty ? .height(compactHeight) : .large }
        }
    }

    enum Destination: Hashable { case all, widgetTap, liveActivity, widgetGuide, privacy }

    /// 낮은 시트(시안 3a·3b의 설정 시트).
    private var quick: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle(title: String(localized: "Settings"), size: 28) { dismiss() }
            CoreSettingsGroup()
                .padding(.top, 12)
            NavigationLink(value: Destination.all) {
                HStack {
                    Text(String(localized: "All settings"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).opacity(0.8)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 4)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 24)
    }
}

/// "설정" 큰 제목 + 오른쪽 "완료".
private struct SheetTitle: View {
    let title: String
    var size: CGFloat = 34
    var back: (() -> Void)? = nil
    let done: () -> Void

    init(title: String, size: CGFloat = 34, back: (() -> Void)? = nil, done: @escaping () -> Void) {
        self.title = title
        self.size = size
        self.back = back
        self.done = done
    }

    var body: some View {
        HStack(spacing: 8) {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, -12)
                .accessibilityLabel(String(localized: "Back"))
            }
            Text(title)
                .font(.system(size: size, weight: .bold))
                .tracking(-0.5)
            Spacer()
            Button(String(localized: "Done"), action: done)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}

/// 시트와 4c 맨 위에 같이 쓰는 세 줄: 기본 휴식(±5초) · 소리 · 햅틱.
private struct CoreSettingsGroup: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        @Bindable var model = timer

        SettingsGroup(topPadding: 0) {
            SettingsRow(title: String(localized: "Default rest"),
                        subtitle: timer.isActive ? String(localized: "Applies from your next rest") : nil) {
                ValueStepper(value: String(localized: "\(timer.settings.restSeconds)s"),
                             label: String(localized: "Default rest"),
                             decrement: { timer.adjustRestSeconds(by: -5) },
                             increment: { timer.adjustRestSeconds(by: 5) })
            }
            SettingsRow(title: String(localized: "Sound")) {
                SegmentedPicker(selection: $model.settings.sound)
            }
            SettingsRow(title: String(localized: "Haptics"), showsDivider: false) {
                SegmentedPicker(selection: $model.settings.haptic)
            }
        }
    }
}

/// 4c 전체 설정. 자주 쓰는 세 줄 + 위젯 안내만 펼쳐 두고 나머지는 "고급 설정"으로 접는다.
private struct AllSettingsView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var pop
    @State private var showsAdvanced = false
    let close: () -> Void

    var body: some View {
        @Bindable var model = timer

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle(title: String(localized: "Settings"), back: { pop() }, done: close)
                CoreSettingsGroup()
                    .padding(.top, 12)
                NotificationStatusView()
                    .padding(.top, 12)
                SettingsGroup(topPadding: 16) {
                    NavigationLink(value: SettingsSheet.Destination.widgetGuide) {
                        SettingsRow(title: String(localized: "How to add widgets"), showsDivider: false) {
                            DisclosureValue(text: "")
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsAdvanced.toggle() }
                } label: {
                    HStack {
                        Text(String(localized: "Advanced settings"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .rotationEffect(.degrees(showsAdvanced ? 90 : 0))
                    }
                    .padding(.horizontal, 4)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .accessibilityValue(showsAdvanced ? String(localized: "On") : String(localized: "Off"))

                if showsAdvanced { advanced(model: $model) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)  // 고급 설정을 펼치면 보이던 흰 스크롤바(시안 수정)
        .background(Color.sheet.ignoresSafeArea())  // 넘어간 화면은 시스템 시트 배경(#1C1C1E)이라 카드가 묻힌다
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    @ViewBuilder
    private func advanced(model: Bindable<RestTimer>) -> some View {
        SectionTitle(title: String(localized: "Alerts"))
        SettingsGroup {
            ToggleRow(title: String(localized: "Final 3 seconds"), subtitle: String(localized: "Sound, haptics and visual countdown"),
                      isOn: model.settings.countdownHaptics)
            ToggleRow(title: String(localized: "Repeat alerts"), subtitle: String(localized: "One extra alert after 30s if another set remains"),
                      isOn: model.settings.repeatAlert, showsDivider: false)
            if !timer.usesRestAlarm && timer.notifications.timeSensitive != .notSupported {
                // 시안 A5: 시간 민감 알림은 앱이 바꿀 수 없어 상태만 보여 주고 설정 앱으로 보낸다.
                Button { openNotificationSettings() } label: {
                    SettingsRow(title: String(localized: "Time Sensitive notifications"),
                                subtitle: String(localized: "Shown right away, even in Focuses that allow them"), showsDivider: false) {
                        DisclosureValue(text: timer.notifications.timeSensitive == .enabled ? String(localized: "On") : String(localized: "Off"))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        if !timer.usesRestAlarm && timer.notifications.timeSensitive == .disabled {
            FocusWarningCard(open: openNotificationSettings)
                .padding(.top, 16)
        }
        NotificationStatusView(showsReadyState: true)
            .padding(.top, 12)

        SectionTitle(title: String(localized: "Timer"))
        SettingsGroup {
            SettingsRow(title: String(localized: "Set goal"), subtitle: String(localized: "Unlimited until you end the workout"), showsDivider: false) {
                ValueStepper(value: timer.goalLabel,
                             label: String(localized: "Set goal"),
                             decrement: { timer.adjustGoal(by: -1) },
                             increment: { timer.adjustGoal(by: 1) })
            }
        }

        SectionTitle(title: String(localized: "Lock Screen"))
        SettingsGroup {
            NavigationLink(value: SettingsSheet.Destination.widgetTap) {
                SettingsRow(title: String(localized: "Widget tap action")) {
                    DisclosureValue(text: timer.settings.widgetTap.label)
                }
            }
            .buttonStyle(.plain)
            NavigationLink(value: SettingsSheet.Destination.liveActivity) {
                SettingsRow(title: "Live Activity", showsDivider: false) {
                    DisclosureValue(text: timer.settings.liveActivity ? String(localized: "On") : String(localized: "Off"))
                }
            }
            .buttonStyle(.plain)
        }

        SectionTitle(title: String(localized: "About"))
        SettingsGroup {
            NavigationLink(value: SettingsSheet.Destination.privacy) {
                SettingsRow(title: String(localized: "Privacy Policy"), showsDivider: false) {
                    DisclosureValue(text: "")
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// 시안 A5 집중 모드 경고. 집중 모드 켜짐 여부는 메시지 앱용 권한이 따로 필요해 읽지 않는다 —
/// 대신 시간 민감 알림이 꺼져 있을 때(집중 모드가 휴식 끝 알림을 막는 경우)만 보여 준다.
private struct FocusWarningCard: View {
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(Color.cardRaised, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Time Sensitive notifications are off"))
                        .font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "When a Focus is on, rest alerts may stay silent. Turn on Time Sensitive notifications for NextSet."))
                        .font(.system(size: 14))
                        .opacity(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(action: open) {
                Text(String(localized: "Open notification settings"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.cardRaised, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// 줄 전체가 토글 버튼(시안: 토글은 줄 어디를 눌러도 된다). VoiceOver 에는 스위치 하나로 읽힌다.
private struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var showsDivider = true

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            SettingsRow(title: title, subtitle: subtitle, showsDivider: showsDivider) {
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(title, isOn: $isOn)
        }
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
        .foregroundStyle(.white.opacity(0.6))
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
        .background(Color.sheet.ignoresSafeArea())
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
                    ToggleRow(title: String(localized: "Lock Screen · Dynamic Island"), subtitle: String(localized: "Show time remaining and controls during rest"),
                              isOn: $isOn, showsDivider: false)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
        }
        .background(Color.sheet.ignoresSafeArea())
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.leading, 4)
            .padding(.top, 24)
    }
}

struct SettingsGroup<Content: View>: View {
    var topPadding: CGFloat = 8
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 16)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, topPadding)
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
                        .opacity(0.6)
                }
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .contentShape(Rectangle())  // .plain 버튼은 그린 곳만 눌린다 — 줄 가운데 빈 곳(Spacer)도 누를 수 있게
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
                        .font(.system(size: fullWidth ? 13 : 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.6))
                        .padding(.horizontal, fullWidth ? 12 : 10)
                        .frame(minWidth: fullWidth ? nil : 48)
                        .frame(maxWidth: fullWidth ? .infinity : nil)
                        .frame(height: fullWidth ? 32 : 44)  // 6d(fullWidth)는 시안에서 그대로
                        .background(isSelected ? Color.brand : Color.clear, in: RoundedRectangle(cornerRadius: fullWidth ? 7 : 10))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.cardRaised, in: RoundedRectangle(cornerRadius: fullWidth ? 9 : 12))
        .fixedSize(horizontal: !fullWidth, vertical: false)  // 줄 안에서 눌려 "약…"으로 잘리지 않게
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}

private struct ValueStepper: View {
    let value: String
    let label: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}
