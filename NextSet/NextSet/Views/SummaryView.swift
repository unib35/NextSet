import SwiftUI

/// 3d — 목표 세트를 설정한 경우만 보이는 완료 요약.
struct SummaryView: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        let session = timer.session

        AdaptiveTimerScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "Workout complete"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
                SetDots(dots: timer.dots)
                    .padding(.top, 14)

            }
        } display: { numberSize in
            VStack(alignment: .leading, spacing: 0) {
                BigNumber(text: "\(session.completedSets)", size: min(120, numberSize), tracking: -6)
                    .foregroundStyle(Color.brand)
                Text(session.completedSets == 1 ? String(localized: "set completed") : String(localized: "sets completed"))
                    .font(.title2.weight(.semibold))
                    .padding(.top, 10)
                VStack(spacing: 0) {
                    StatRow(label: String(localized: "Total rest"), value: RestTimer.format(session.totalRested))
                    StatRow(label: String(localized: "Average rest"), value: RestTimer.format(timer.averageRest))
                    StatRow(label: String(localized: "Skipped rests"), value: String(localized: "\(session.skippedCount) times"))
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.card).frame(height: 1)
                }
                .padding(.top, 36)
            }
            .frame(maxHeight: .infinity)

        } controls: {
            VStack(spacing: 6) {
                Button(action: timer.startOver) {
                    PillLabel(title: String(localized: "Go again"), fill: .brand, foreground: .black, height: 64, fontSize: 20)
                }
                Button(action: timer.endWorkout) {
                    Text(String(localized: "Finish"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                }
                .padding(.top, 6)
            }
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.white)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .opacity(0.7)
            Spacer()
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.card).frame(height: 1)
        }
    }
}
