import Foundation

/// 외부 인텐트·저장값·기기 동기화가 숫자 변환이나 누적 연산을 깨뜨리지 않게 하는 공통 경계.
enum TimerValidation {
    static let maxRest: TimeInterval = 24 * 60 * 60
    static let maxTotal: TimeInterval = 366 * 24 * 60 * 60
    static let maxCount = 1_000_000

    static func seconds(_ interval: TimeInterval) -> Int {
        guard interval.isFinite else { return 0 }
        return Int(interval.clamped(to: 0...maxTotal).rounded(.up))
    }
}

extension TimerSettings {
    func validated() -> Self {
        var value = self
        value.restSeconds = restSeconds.clamped(to: Self.restRange)
        value.recentSeconds = recentSeconds.map { $0.clamped(to: Self.restRange) }
        value.goalSets = goalSets.clamped(to: Self.goalRange)
        return value
    }
}

extension TimerSession {
    /// 일관성이 깨진 진행 상태만 초기화한다. 별도 저장된 운동 기록은 그대로 둔다.
    func validated() -> Self {
        guard restDuration.isFinite, (0...TimerValidation.maxRest).contains(restDuration),
              pausedRemaining.isFinite, (0...TimerValidation.maxRest).contains(pausedRemaining),
              totalRested.isFinite, (0...TimerValidation.maxTotal).contains(totalRested),
              (0...TimerValidation.maxCount).contains(completedSets),
              (0...TimerValidation.maxCount).contains(skippedCount),
              restCount.map({ (0...TimerValidation.maxCount).contains($0) }) ?? true,
              [startedAt, endDate, doneAt].compactMap({ $0 }).allSatisfy({
                  $0.timeIntervalSince1970.isFinite && $0 >= .distantPast && $0 <= .distantFuture
              }) else { return TimerSession() }
        if phase == .running && (endDate == nil || restDuration < 1) { return TimerSession() }
        if phase == .paused && (pausedRemaining < 1 || pausedRemaining > restDuration) { return TimerSession() }
        var value = self
        if phase != .running { value.endDate = nil }
        if phase != .paused { value.pausedRemaining = 0 }
        return value
    }
}

extension WorkoutRecord {
    var isValid: Bool {
        startedAt.timeIntervalSince1970.isFinite && endedAt.timeIntervalSince1970.isFinite
        && endedAt >= startedAt && startedAt >= .distantPast && endedAt <= .distantFuture
        && totalRested.isFinite && (0...TimerValidation.maxTotal).contains(totalRested)
        && (0...TimerValidation.maxCount).contains(completedSets)
        && (0...TimerValidation.maxCount).contains(restCount)
        && (0...TimerValidation.maxCount).contains(skippedCount)
    }
}
