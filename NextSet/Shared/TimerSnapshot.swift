import Foundation

/// 설정 + 세션에서 파생되는 값. 앱(`RestTimer`)과 위젯이 **같은 계산**을 쓰기 위해 여기 모았다.
/// 시각(`now`)에 따라 달라지는 값은 `now`를 받는다 — 위젯은 타임라인 항목마다 다른 시각을 넣는다.
struct TimerSnapshot {
    var settings: TimerSettings
    var session: TimerSession

    init(settings: TimerSettings, session: TimerSession) {
        self.settings = settings.validated()
        self.session = session.validated()
    }

    /// 저장소에서 바로 읽는다 (위젯용).
    init(from defaults: UserDefaults = TimerStore.shared) {
        self.init(settings: TimerStore.loadSettings(from: defaults),
                  session: TimerStore.loadSession(from: defaults))
    }

    var isActive: Bool { session.phase == .running || session.phase == .paused }
    var hasGoal: Bool { settings.mode == .sets && settings.goalSets > 0 }
    var nextSetNumber: Int { session.completedSets + 1 }

    /// 위젯 탭으로 시작할 때 쓰는 시간 — 마지막으로 시작한 프리셋, 없으면 기본 휴식.
    var lastPresetSeconds: Int { settings.recentSeconds ?? settings.restSeconds }

    /// 앱이 잠들어 있으면 저장된 세션은 `running` 인데 종료 시각은 이미 지났을 수 있다.
    /// 위젯은 이 경우를 "휴식 끝"으로 보여야 한다.
    func hasRestEnded(at now: Date) -> Bool {
        session.phase == .running && (session.endDate.map { $0 <= now } ?? false)
    }

    func remaining(at now: Date) -> TimeInterval {
        switch session.phase {
        case .running: (session.endDate ?? now).timeIntervalSince(now).clamped(to: 0...session.restDuration)
        case .paused: session.pausedRemaining
        default: session.restDuration
        }
    }

    /// 끝낸 세트 수. 휴식은 세트를 끝낸 뒤 시작하므로 휴식 중이면 방금 끝낸 세트까지 센다
    /// (첫 휴식 중에도 "세트 시작 전"이 아니라 "세트 1 완료" — 2026-10 시안).
    var finishedSets: Int { session.completedSets + (isActive && settings.mode == .sets ? 1 : 0) }

    /// 전체 세트에 일대일 대응한다. 실제 배열을 만들지 않아 무제한 세트도 메모리가 일정하다.
    /// 카운트다운 모드와 0세트에서는 점을 그리지 않는다(2026-10 시안).
    var dots: SetProgress {
        let finished = session.phase == .finished
        let done = finishedSets
        let total = settings.mode == .single ? 0
            : hasGoal ? settings.goalSets
            : finished ? done
            : done == 0 ? 0 : done + 1
        return SetProgress(total: total, completed: done, finished: finished)
    }

    var setCaption: String {
        if settings.mode == .single { return String(localized: "Single") }
        let done = finishedSets
        if hasGoal { return String(localized: "Sets \(done)/\(settings.goalSets)") }
        return done == 0 ? String(localized: "No sets yet") : String(localized: "Set \(done) complete")
    }
}

/// 점의 인덱스는 운동 내 세트 번호(0부터). 스크롤 중에도 같은 세트의 identity를 유지한다.
struct SetProgress: RandomAccessCollection, Equatable {
    let total: Int
    let completed: Int
    let finished: Bool
    var startIndex: Int { 0 }
    var endIndex: Int { total }
    var focusIndex: Int { Swift.max(0, Swift.min(completed, total - 1)) }
    var pastCount: Int { finished ? total : Swift.min(completed, total) }
    subscript(index: Int) -> SetDot {
        precondition(indices.contains(index))
        if finished || index < completed { return .past }
        return index == completed ? .current : .upcoming
    }
}
