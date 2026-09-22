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

    /// 점은 전체 세트 수가 아니라 현재 세트 주변의 최대 5개만 표시한다.
    /// Watch·소형 위젯·Dynamic Island에서도 폭이 일정하게 제한된다.
    static let maxVisibleDots = 5

    var dots: [SetDot] {
        let sets = session.completedSets
        let finished = session.phase == .finished
        let total = settings.mode == .single ? 1
            : hasGoal ? settings.goalSets
            : finished ? max(1, sets) : sets + 1
        let count = min(Self.maxVisibleDots, total)
        // 목표가 있으면 현재 위치를 가운데 두고, 양 끝에서는 범위 안으로 이동한다.
        // 무제한 모드는 마지막 점이 현재 위치가 되어 100세트 이후에도 사라지지 않는다.
        let start = min(max(0, sets - count / 2), total - count)
        return (start..<(start + count)).map { index in
            if index < sets || finished { return .past }
            return index == sets ? .current : .upcoming
        }
    }

    var setCaption: String {
        if settings.mode == .single { return String(localized: "Single") }
        if hasGoal { return String(localized: "Sets \(session.completedSets)/\(settings.goalSets)") }
        return session.completedSets == 0 ? String(localized: "No sets yet") : String(localized: "Set \(session.completedSets) complete")
    }
}
