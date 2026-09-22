import SwiftUI

/// 최근 운동(T-58). 설정 시트와 같은 커스텀 스타일(검정 시트, 둥근 카드 그룹, 큰 제목).
/// 삭제는 왼쪽으로 밀기 — 그래서 목록은 `List`를 쓰되 배경·구분선을 설정 시트 카드처럼 입혔다.
struct WorkoutHistoryView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: WorkoutRecord?

    var body: some View {
        List {
            Section {
                HStack {
                    Text(String(localized: "Recent workouts"))
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                    Spacer()
                    Button(String(localized: "Done")) { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
                .padding(.top, 10)
                Text(String(localized: "The last 30 workouts saved on this device. Total rest includes rest up to the moment you end a workout and excludes pauses."))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 6)
                    .padding(.bottom, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)

            if timer.history.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.brand)
                        Text(String(localized: "No workouts yet"))
                            .font(.system(size: 17, weight: .semibold))
                        Text(String(localized: "A summary is saved when you end a workout or reach your set goal."))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .listRowBackground(Color.card)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(timer.history) { record in
                        HistoryRow(record: record) { pendingDelete = record }
                    }
                    .onDelete { offsets in timer.deleteHistory(at: offsets) }
                } header: {
                    Text(String(localized: "History"))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(nil)
                        .padding(.leading, 0)
                } footer: {
                    Text(String(localized: "Tap the trash icon or swipe left to delete from this device. Records from your paired iPhone or Watch also appear after syncing."))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 0)
                }
                .listRowBackground(Color.card)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparatorTint(.white.opacity(0.08))
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(18)
        .contentMargins(.horizontal, 24, for: .scrollContent)  // 설정 시트와 같은 좌우 여백
        .scrollContentBackground(.hidden)
        .background(Color.sheet)
        .environment(\.defaultMinListRowHeight, 44)
        .tint(Color.brand)
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.sheet)
        .presentationCornerRadius(38)
        .confirmationDialog(String(localized: "Delete this record?"), isPresented: Binding(get: { pendingDelete != nil },
                                                                      set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { record in
            Button(String(localized: "Delete"), role: .destructive) {
                if let index = timer.history.firstIndex(where: { $0.id == record.id }) {
                    timer.deleteHistory(at: IndexSet(integer: index))
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { record in
            Text(record.mode == .single ? String(localized: "Countdown record") : String(localized: "\(record.completedSets) sets · Rest \(RestTimer.format(record.totalRested))"))
        }
    }
}

/// 한 줄: 날짜 · "N세트 완료" · 총/평균/건너뜀. 목표 달성이면 ✓, 맨 오른쪽에 휴지통(명시적 삭제).
private struct HistoryRow: View {
    let record: WorkoutRecord
    let onDelete: () -> Void

    private var title: String {
        record.mode == .single ? String(localized: "Countdown") : String(localized: "\(record.completedSets) sets completed")
    }

    private var detail: String {
        var parts = [String(localized: "Rest \(RestTimer.format(record.totalRested))")]
        if record.restCount > 0 { parts.append(String(localized: "Average \(RestTimer.format(record.averageRest))")) }
        if record.skippedCount > 0 { parts.append(String(localized: "Skipped \(record.skippedCount)")) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.endedAt, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .monospacedDigit()
            Spacer(minLength: 8)
            if record.reachedGoal {
                Label(String(localized: "Goal reached"), systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand)
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.danger)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Delete record"))
        }
    }
}
