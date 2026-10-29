import SwiftUI

/// 3a — 시간 선택. 프리셋 가로 스크롤 · 우상단 기어 = 설정 시트. 세밀한 조절(±5초)은 설정의 기본 휴식.
struct SetupView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(FirstRunHints.self) private var hints
    @State private var showsHistory = false
    @State private var showsWidgetGuide = false

    var body: some View {
        AdaptiveTimerScreen {
            // 세트가 있으면 모드 탭 자리에 "종료"(길게 누르기). 머리 높이는 3b와 같다.
            TimerHeader(showsCaption: timer.settings.mode == .sets) {
                if showsEndButton {
                    EndWorkoutButton()
                } else {
                    HStack(spacing: 18) {
                        modeTab(String(localized: "Set rest"), mode: .sets)
                        modeTab(String(localized: "Countdown"), mode: .single)
                    }
                }
            } dotsTrailing: {
                // 레이아웃 밖(overlay)에 둬서 머리 높이를 3b와 같게 유지한다.
                Button {
                    showsHistory = true
                } label: {
                    Label(String(localized: "Recent workouts"), systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.brand)
                .offset(y: 14)
            }
        } display: { numberSize in
            NumberSlot(text: "\(timer.settings.restSeconds)", size: numberSize) {
                Text(Self.unitLabel(seconds: timer.settings.restSeconds, single: timer.settings.mode == .single))
                    .font(.system(size: 17))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } controls: {
            VStack(spacing: 20) {
                firstRunHint
                PresetStrip()
                actionRow
            }
            .frame(minHeight: TimerControlsMetrics.minHeight, alignment: .bottom)
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showsWidgetGuide) {
            WidgetGuideView(presentation: .sheet)
        }
        .sheet(isPresented: $showsHistory) {
            WorkoutHistoryView().environment(timer)
        }
    }

    /// 세트 모드에서 세트가 하나라도 있으면 모드 탭 대신 종료 버튼(시안 3a).
    private var showsEndButton: Bool {
        timer.settings.mode == .sets && timer.session.completedSets > 0
    }

    /// 큰 숫자는 초로 두고, 1분이 넘으면 아래 줄에 분·초로 풀어 쓴다(시안 unitLabel).
    static func unitLabel(seconds: Int, single: Bool) -> String {
        let minutes = seconds / 60, rest = seconds % 60
        guard seconds > 60 else { return single ? String(localized: "sec") : String(localized: "sec rest") }
        switch (single, rest) {
        case (true, 0): return String(localized: "\(minutes) min")
        case (true, _): return String(localized: "\(minutes) min \(rest) sec")
        case (false, 0): return String(localized: "\(minutes) min rest")
        case (false, _): return String(localized: "\(minutes) min \(rest) sec rest")
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

    private func modeTab(_ title: String, mode: TimerMode) -> some View {
        let isSelected = timer.settings.mode == mode
        return Button {
            timer.selectMode(mode)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
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

    private var actionRow: some View {
        Button(action: timer.start) {
            PillLabel(title: timer.startLabel, fill: .brand, foreground: .black, height: 64, fontSize: 20)
        }
        .buttonStyle(.pressable)
    }
}

/// 3b·3a 하단 영역의 최소 높이. 두 화면이 같아야 휴식을 시작해도 숫자가 움직이지 않는다(시안 148px).
enum TimerControlsMetrics {
    static let minHeight: CGFloat = 148
}

/// 3a 프리셋 줄 — 화면 끝까지 이어지는 가로 스크롤, 양 끝은 흐리게. 멈추면 가운데에 맞춰 서고, 탭하면 그 항목이 가운데로 온다.
private struct PresetStrip: View {
    @Environment(RestTimer.self) private var timer
    @State private var centered: Int?
    @State private var width: CGFloat = 0
    private let itemWidth: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(TimerSettings.presets, id: \.self) { seconds in
                    item(seconds)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centered, anchor: .center)
        .safeAreaPadding(.horizontal, max(0, (width - itemWidth) / 2))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 40)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 40)
            }
        }
        .padding(.horizontal, -24)  // 화면 가장자리까지(screenPadding 상쇄)
        .onAppear { centered = nearestPreset(to: timer.settings.restSeconds) }
        .onChange(of: timer.settings.restSeconds) { _, seconds in
            withAnimation(.smooth) { centered = nearestPreset(to: seconds) }
        }
    }

    private func item(_ seconds: Int) -> some View {
        let isSelected = timer.settings.restSeconds == seconds
        let isRecent = timer.settings.recentSeconds == seconds && !isSelected
        return Button {
            timer.setRestSeconds(seconds)
        } label: {
            VStack(spacing: 6) {
                Text(Self.label(seconds))
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(String(localized: "Recent"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .opacity(isRecent ? 0.6 : 0)
            }
            .padding(.vertical, 8)
            .frame(width: itemWidth)
            .overlay(alignment: .bottom) {
                Rectangle().fill(isSelected ? Color.brand : Color.clear).frame(height: 2)
            }
            .foregroundStyle(isSelected ? Color.brand : Color.white.opacity(0.55))
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .id(seconds)
        .accessibilityLabel(String(localized: "\(seconds)s"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 1분이 넘으면 분:초(75 → 1:15). 1분까지는 초.
    static func label(_ seconds: Int) -> String {
        seconds > 60 ? "\(seconds / 60):" + String(format: "%02d", seconds % 60) : "\(seconds)"
    }

    private func nearestPreset(to seconds: Int) -> Int {
        TimerSettings.presets.min { abs($0 - seconds) < abs($1 - seconds) } ?? seconds
    }
}
