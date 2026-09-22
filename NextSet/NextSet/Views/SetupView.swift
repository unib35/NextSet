import SwiftUI

/// 3a — 시간 선택. 우상단 기어 = 설정 시트.
struct SetupView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(FirstRunHints.self) private var hints
    @State private var showsSettings = false
    @State private var showsHistory = false
    @State private var showsWidgetGuide = false

    var body: some View {
        AdaptiveTimerScreen {
            VStack(spacing: 0) {
                header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(timer.setCaption).font(.subheadline).foregroundStyle(.secondary)
                        SetDots(dots: timer.dots)
                    }
                    Spacer()
                    Button {
                        showsHistory = true
                    } label: {
                        Label(String(localized: "Recent workouts"), systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.brand)
                }
                .padding(.top, 8)

            }
        } display: { numberSize in
            VStack(spacing: 0) {
                BigNumber(text: "\(timer.settings.restSeconds)", size: min(200, numberSize), tracking: -6)
                    .foregroundStyle(Color.brand)
                Text(timer.settings.mode == .single ? String(localized: "sec") : String(localized: "sec rest"))
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 10)
                HStack(spacing: 28) {
                    stepButton("minus", label: String(localized: "Subtract 5 seconds")) { timer.adjustRestSeconds(by: -5) }
                    stepButton("plus", label: String(localized: "Add 5 seconds")) { timer.adjustRestSeconds(by: 5) }
                }
                .padding(.top, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } controls: {
            VStack(spacing: 20) {
                firstRunHint
                presetRow
                actionRow
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showsWidgetGuide) {
            WidgetGuideView(presentation: .sheet)
        }
        .sheet(isPresented: $showsHistory) {
            WorkoutHistoryView().environment(timer)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsSheet()
                .environment(timer)
        }
    }

    /// 6c 첫 종료 후 Watch 안내(페어링된 경우만) → 6d 두 번째 종료 후 위젯 안내. 한 번에 하나, 각각 한 번만.
    @ViewBuilder
    private var firstRunHint: some View {
        let ended = timer.endedWorkoutCount
        if hints.showsWatchHint(endedWorkouts: ended, isWatchPaired: RestSync.isWatchPaired) {
            HintCard(
                systemImage: "applewatch",
                text: String(localized: "Start and pause on Apple Watch too. Start on your wrist and see it on your phone."),
                dismissLabel: String(localized: "Got it")
            ) { hints.markWatchSeen() }
            .transition(.opacity)
        } else if hints.showsWidgetGuideHint(endedWorkouts: ended) {
            HintCard(
                systemImage: "square.grid.2x2",
                text: String(localized: "Add a widget to start rest without opening the app first."),
                primary: (
                    String(localized: "View"),
                    {
                        hints.markWidgetGuideSeen()
                        showsWidgetGuide = true
                    }
                ),
                dismissLabel: String(localized: "Close")
            ) { hints.markWidgetGuideSeen() }
            .transition(.opacity)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 18) {
                modeTab(String(localized: "Set rest"), mode: .sets)
                modeTab(String(localized: "Countdown"), mode: .single)
            }
            Spacer()
            HStack(spacing: 12) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .background(Color.card, in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(String(localized: "Settings"))
            }
        }
    }

    private func modeTab(_ title: String, mode: TimerMode) -> some View {
        let isSelected = timer.settings.mode == mode
        return Button {
            timer.selectMode(mode)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
                Rectangle()
                    .fill(isSelected ? Color.brand : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    private var presetRow: some View {
        HStack(spacing: 0) {
            ForEach(TimerSettings.presets, id: \.self) { seconds in
                let isSelected = timer.settings.restSeconds == seconds
                let isRecent = timer.settings.recentSeconds == seconds && !isSelected
                Button {
                    timer.setRestSeconds(seconds)
                } label: {
                    VStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text("\(seconds)")
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                            Text(String(localized: "Recent"))
                                .font(.caption.weight(.semibold))
                                .tracking(0.3)
                                .opacity(isRecent ? 0.6 : 0)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        Rectangle()
                            .fill(isSelected ? Color.brand : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundStyle(isSelected ? Color.brand : Color.white.opacity(0.65))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "\(seconds)s"))
                if seconds != TimerSettings.presets.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var actionRow: some View {
        VStack(spacing: 6) {
            Button(action: timer.start) {
                PillLabel(title: timer.startLabel, fill: .brand, foreground: .black, height: 64, fontSize: 20)
            }
            if timer.canEndWorkout { EndWorkoutButton() }
        }
        .buttonStyle(.pressable)
    }
}
