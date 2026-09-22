import SwiftUI
import WidgetKit

/// 3e 잠금화면 위젯 — 대기 중엔 마지막 프리셋 숫자, 탭하면 그 시간으로 바로 시작.
/// 실행 중엔 남은 시간이 실시간으로 줄어든다 (`Text(timerInterval:)`, 타임라인 갱신 없이 시스템이 그린다).
struct LockScreenWidget: Widget {
    static let kind = "kr.co.lee.NextSet.lockscreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RestTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .widgetURL(entry.url)
        }
        .configurationDisplayName(String(localized: "NextSet"))
        .description(String(localized: "Tap to start your last preset. See the time remaining during rest."))
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RestEntry

    var body: some View { LockScreenWidgetView(entry: entry, family: family) }
}

struct LockScreenWidgetView: View {
    let entry: RestEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        #if os(watchOS)
        case .accessoryCorner: corner
        #endif
        default: rectangular
        }
    }

    #if os(watchOS)
    // MARK: 코너 (워치) — 숫자 + 곡선 라벨
    private var corner: some View {
        Group {
            switch entry.state {
            case .idle(let seconds):
                Text("\(seconds)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .widgetLabel(String(localized: "NextSet"))
            case .running(let end):
                Text(timerInterval: entry.date...max(end, entry.date), countsDown: true, showsHours: false)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .widgetLabel(String(localized: "Resting"))
            case .paused(let remaining):
                Text(formatRemaining(remaining))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .widgetLabel(String(localized: "Paused"))
            case .ended(let nextSet):
                Text("\(nextSet)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .widgetLabel(String(localized: "Start set \(nextSet)"))
            case .finished:
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .widgetLabel(String(localized: "Workout complete"))
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
    #endif

    // MARK: 원형 — 시안 3e의 "60" 원 버튼

    private var circular: some View {
        ZStack {
            switch entry.state {
            case .idle(let seconds):
                VStack(spacing: -2) {
                    Text("\(seconds)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    Text(String(localized: "sec"))
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                }
            case .running(let end):
                ProgressView(timerInterval: entry.date...max(end, entry.date), countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    Text(timerInterval: entry.date...max(end, entry.date), countsDown: true, showsHours: false)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                }
                .progressViewStyle(.circular)
            case .paused(let remaining):
                VStack(spacing: 0) {
                    Image(systemName: "pause.fill").font(.system(size: 11))
                    Text(formatRemaining(remaining))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                }
            case .ended(let nextSet):
                VStack(spacing: -2) {
                    Text("\(nextSet)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .widgetAccentable()
                    Text(String(localized: "Set")).font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
            case .finished:
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    // MARK: 직사각형 — 제목 + 상태 + 세트 점

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "NextSet"))
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.8)
            Group {
                switch entry.state {
                case .idle(let seconds):
                    Text(String(localized: "Tap for \(seconds)s rest"))
                case .running(let end):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(timerInterval: entry.date...max(end, entry.date), countsDown: true, showsHours: false)
                            .monospacedDigit()
                            .widgetAccentable()
                        Text(String(localized: "Resting · Set \(entry.snapshot.nextSetNumber)"))
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.7)
                    }
                case .paused(let remaining):
                    Text(String(localized: "Paused · \(formatRemaining(remaining))"))
                        .monospacedDigit()
                case .ended(let nextSet):
                    Text(String(localized: "Rest over · Start set \(nextSet)"))
                        .widgetAccentable()
                case .finished:
                    Text(String(localized: "Workout complete ✓"))
                }
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            WidgetSetDots(dots: entry.snapshot.dots, monochrome: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: 한 줄

    private var inline: some View {
        Group {
            switch entry.state {
            case .idle(let seconds): Text(String(localized: "NextSet · \(seconds)s"))
            case .running(let end): Text("Rest \(Text(timerInterval: entry.date...max(end, entry.date), countsDown: true, showsHours: false))")
            case .paused(let remaining): Text(String(localized: "Paused · \(formatRemaining(remaining))"))
            case .ended(let nextSet): Text(String(localized: "Rest over · Set \(nextSet)"))
            case .finished: Text(String(localized: "NextSet · Workout complete"))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

#Preview("Idle", as: .accessoryCircular) {
    LockScreenWidget()
} timeline: {
    RestEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    RestEntry.placeholder
}
