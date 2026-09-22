import Foundation

/// 위젯·Live Activity 가 한 시점에 보여줄 상태. 저장된 세션이 `running`이어도 종료 시각이 지났으면(앱이 잠든 경우) `ended`.
enum RestDisplay: Equatable {
    case idle(seconds: Int)          // 대기 — 탭/버튼으로 이 시간으로 시작
    case running(end: Date)          // 휴식 중 — 카운트다운
    case paused(remaining: TimeInterval)
    case ended(nextSet: Int)         // 휴식 끝 — 다음 세트 시작할 시간
    case finished                    // 목표 세트 달성 (3d)

    /// - Parameter isStale: Live Activity 에서 `context.isStale`. 앱이 update 를 못 한 채 종료 시각이 지났다는 뜻.
    static func from(_ snapshot: TimerSnapshot, at now: Date, isStale: Bool = false) -> RestDisplay {
        switch snapshot.session.phase {
        case .finished: return .finished
        case .done: return .ended(nextSet: snapshot.nextSetNumber)
        case .running where isStale || snapshot.hasRestEnded(at: now):
            let completed = snapshot.session.completedSets + (snapshot.settings.mode == .sets ? 1 : 0)
            if snapshot.settings.mode == .single || (snapshot.hasGoal && completed >= snapshot.settings.goalSets) {
                return .finished
            }
            return .ended(nextSet: completed + 1)
        case .running: return .running(end: snapshot.session.endDate ?? now)
        case .paused: return .paused(remaining: snapshot.session.pausedRemaining)
        case .idle: return .idle(seconds: snapshot.lastPresetSeconds)
        }
    }

    var isEnded: Bool { if case .ended = self { return true } else { return false } }
    var isActive: Bool {
        switch self {
        case .running, .paused: true
        default: false
        }
    }
}

func formatRemaining(_ interval: TimeInterval) -> String {
    let total = TimerValidation.seconds(interval)
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
