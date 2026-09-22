import Foundation

/// 위젯·Live Activity·제어 센터 버튼이 시키는 일. 처리는 앱의 `RestTimer.perform(_:)` 한 곳.
enum TimerAction: Equatable {
    case start(seconds: Int?)  // nil 이면 마지막 프리셋
    case togglePause
    case add(seconds: Int)  // 진행 중인 휴식에 초를 더하거나 뺀다 (−10 / +10 / +30)
    case skip
    case endWorkout
    case startOver
    case controlToggle  // 제어 센터 토글: 대기 → 시작, 실행 중 → 일시정지, 일시정지 → 재개
    case setControlRunning(Bool)  // 제어 센터가 요청한 상태를 멱등 적용
    case restartRest    // 이 휴식을 처음부터 다시 (워치 4e 메뉴)
}
