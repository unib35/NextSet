#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
import WidgetKit

/// iOS 26 휴식 끝 알람에서 "+30초 더 쉬기"를 누른 뒤의 30초 카운트다운(시안 A2).
/// AlarmKit 은 카운트다운이 있는 알람에 이 위젯이 없으면 알람을 닫아 버릴 수 있다(Apple 문서) — 그래서 단순해도 둔다.
/// 휴식 자체의 Live Activity 는 `RestLiveActivity`. 이건 알람이 울린 뒤에만 잠깐 뜬다.
@available(iOS 26.0, *)
struct RestAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RestAlarmMetadata>.self) { context in
            HStack(spacing: 16) {
                AlarmCountdownText(state: context.state)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brand)
                Text(title(context.attributes, state: context.state))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(title(context.attributes, state: context.state))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmCountdownText(state: context.state)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brand)
                }
            } compactLeading: {
                Image(systemName: "alarm").foregroundStyle(Color.brand)
            } compactTrailing: {
                AlarmCountdownText(state: context.state)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brand)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "alarm").foregroundStyle(Color.brand)
            }
            .keylineTint(Color.brand)
        }
    }

    private func title(_ attributes: AlarmAttributes<RestAlarmMetadata>, state: AlarmPresentationState) -> LocalizedStringResource {
        if case .countdown = state.mode, let countdown = attributes.presentation.countdown { return countdown.title }
        return attributes.presentation.alert.title
    }
}

@available(iOS 26.0, *)
private struct AlarmCountdownText: View {
    let state: AlarmPresentationState

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                Text(timerInterval: Date.now...max(countdown.fireDate, .now), countsDown: true, showsHours: false)
            case .paused(let paused):
                Text(formatRemaining(paused.totalCountdownDuration - paused.previouslyElapsedDuration))
            default:
                Image(systemName: "alarm")
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
#endif
