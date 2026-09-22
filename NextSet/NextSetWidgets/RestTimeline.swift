import WidgetKit

/// 모든 위젯이 쓰는 타임라인 항목. 시각이 다른 항목이 같은 스냅숏을 공유할 수 있다
/// (실행 중 → 종료 시각에 "휴식 끝"으로 바뀌는 항목).
struct RestEntry: TimelineEntry {
    let date: Date
    let snapshot: TimerSnapshot

    /// 이 항목 시점의 표시 상태.
    var state: RestDisplay { RestDisplay.from(snapshot, at: date) }

    /// 대기 상태에서 탭하면 즉시 시작(설정 4c "위젯 탭 동작"이 즉시 시작일 때), 그 외에는 앱만 연다
    /// (`ContentView.onOpenURL` → `RestTimer.handleURL`).
    var url: URL {
        if case .idle = state, snapshot.settings.widgetTap == .start { return URL(string: "nextset://start")! }
        return URL(string: "nextset://open")!
    }

    static let placeholder = RestEntry(date: .now, snapshot: TimerSnapshot(settings: TimerSettings(), session: TimerSession()))
}

struct RestTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RestEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RestEntry) -> Void) {
        completion(RestEntry(date: .now, snapshot: TimerSnapshot()))
    }

    /// 지금 항목 하나 + 실행 중이면 종료 시각에 "휴식 끝" 항목. 그 밖의 갱신은 앱이 reload 로 밀어준다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RestEntry>) -> Void) {
        let now = Date.now
        let snapshot = TimerSnapshot()
        var entries = [RestEntry(date: now, snapshot: snapshot)]
        if snapshot.session.phase == .running, let end = snapshot.session.endDate, end > now {
            entries.append(RestEntry(date: end, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}
