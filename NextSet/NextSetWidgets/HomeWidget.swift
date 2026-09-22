import AppIntents
import SwiftUI
import WidgetKit

/// 5b 홈 화면 위젯 — 소형(탭 = 즉시 시작 / 실행 중엔 앱 열기), 중형(프리셋 3개 바로 시작, 실행 중엔 +30·일시정지·건너뛰기).
/// 중형의 버튼은 AppIntent(`Shared/TimerIntents.swift`)라 앱을 열지 않고 동작한다. 소형 전체 탭은 위젯 규칙상 딥링크(앱 열기).
struct HomeWidget: Widget {
    static let kind = "kr.co.lee.NextSet.home"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RestTimelineProvider()) { entry in
            HomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "NextSet"))
        .description(String(localized: "Start rest with a tap and see the time remaining on your Home Screen."))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

/// 위젯 환경에서 family 를 읽어 넘긴다. (`HomeWidgetView`는 family 를 인자로 받아 앱의 위젯 갤러리에서도 그릴 수 있다.)
struct HomeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RestEntry

    var body: some View {
        HomeWidgetView(entry: entry, family: family)
            .containerBackground(for: .widget) { HomeWidgetView.backgroundColor(for: entry.state) }
    }
}

struct HomeWidgetView: View {
    let entry: RestEntry
    let family: WidgetFamily

    private var display: RestDisplay { entry.state }
    private var isEnded: Bool { display.isEnded }
    private var foreground: Color { isEnded ? .black : .white }

    static func backgroundColor(for display: RestDisplay) -> Color {
        display.isEnded ? .brand : .black
    }

    var body: some View {
        Group {
            if family == .systemSmall { small } else { medium }
        }
        .foregroundStyle(foreground)
    }

    // MARK: 공통 조각 (시안 5b 의 ccLabel / ccTitle)

    private var caption: String {
        switch display {
        case .idle: String(localized: "Start rest")
        case .running: String(localized: "Resting")
        case .paused: String(localized: "Resume")
        case .ended(let nextSet): String(localized: "Set \(nextSet)")
        case .finished: String(localized: "Done")
        }
    }

    private var title: String {
        switch display {
        case .idle: String(localized: "NextSet")
        case .running: String(localized: "Resting")
        case .paused: String(localized: "Paused")
        case .ended(let nextSet): String(localized: "Rest over · Set \(nextSet)")
        case .finished: String(localized: "Workout complete")
        }
    }

    // MARK: 소형 — padding 18, 제목 13/600 .7 + 점 5px, 숫자 64 line-height .9, 캡션 13/600 .75 (margin 8)

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "NextSet"))
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.7)
                Spacer()
                WidgetSetDots(dots: entry.snapshot.dots, size: 5, onOrange: isEnded)
            }
            Spacer(minLength: 0)
            BigNumberLabel(display: display, referenceDate: entry.date, size: 64, onOrange: isEnded)
                .frame(height: 58)
            Text(caption)
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.75)
                .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(entry.url)
    }

    // MARK: 중형 — padding 18/20, 간격 14, 제목 15/600 + 캡션 13 .6, 숫자 44, 버튼 44 r14

    private var medium: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(entry.snapshot.setCaption)
                        .font(.system(size: 13))
                        .opacity(0.6)
                }
                Spacer()
                BigNumberLabel(display: display, referenceDate: entry.date, size: 44, onOrange: isEnded)
                    .frame(height: 44)
            }
            HStack(spacing: 8) {
                switch display {
                case .running, .paused:
                    IntentPill("+10", intent: AddSecondsIntent(seconds: 10), onOrange: isEnded)
                    IntentPill("+30", intent: AddSecondsIntent(seconds: 30), onOrange: isEnded)
                    IntentPill(isPaused ? String(localized: "Resume") : String(localized: "Pause"), intent: TogglePauseIntent(), onOrange: isEnded)
                    IntentPill(String(localized: "Skip"), intent: SkipRestIntent(), prominent: true, onOrange: isEnded)
                case .finished:
                    IntentPill(String(localized: "Go again"), intent: StartOverIntent(), prominent: true, onOrange: isEnded)
                default:
                    ForEach(Self.quickPresets, id: \.self) { seconds in
                        IntentPill("\(seconds)", intent: StartRestIntent(seconds: seconds),
                                   prominent: seconds == entry.snapshot.settings.restSeconds, onOrange: isEnded, bold: true)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var isPaused: Bool { if case .paused = display { return true } else { return false } }

    /// 시안 5b: 프리셋 3개는 30 · 60 · 90 고정, 현재 기본 휴식과 같은 것을 오렌지로.
    static let quickPresets = [30, 60, 90]
}

#Preview("Small", as: .systemSmall) {
    HomeWidget()
} timeline: {
    RestEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    HomeWidget()
} timeline: {
    RestEntry.placeholder
}
