import AppIntents

/// 인텐트 → 앱 연결점. 앱이 시작할 때 `handler`를 등록한다 (`AppDelegate`).
/// 위젯 익스텐션에도 이 파일이 컴파일되지만, 아래 인텐트는 전부 `LiveActivityIntent`라서
/// **시스템이 앱 프로세스에서 실행한다**(앱이 꺼져 있으면 백그라운드로 띄운다). 익스텐션에서 `perform`이 불리는 일은 없다.
@MainActor
enum TimerIntentRunner {
    static var handler: ((TimerAction) -> Void)?

    enum RunnerError: Error { case unavailable }

    static func perform(_ action: TimerAction) throws {
        guard let handler else { throw RunnerError.unavailable }
        handler(action)
    }
}

struct StartRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start rest"
    static let description = IntentDescription("Start rest using your last preset or a duration in seconds.")

    @Parameter(title: "Seconds") var seconds: Int?

    init() {}
    init(seconds: Int?) { self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.start(seconds: seconds))
        return .result()
    }
}

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause / Resume"
    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.togglePause)
        return .result()
    }
}

struct AddSecondsIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust rest time"
    static let description = IntentDescription("Add or subtract seconds during rest (−10 / +10 / +30).")

    @Parameter(title: "Seconds", default: 30) var seconds: Int

    init() {}
    init(seconds: Int) { self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.add(seconds: seconds))
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip"
    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.skip)
        return .result()
    }
}

struct EndWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End workout"
    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.endWorkout)
        return .result()
    }
}

struct StartOverIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Go again"
    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.startOver)
        return .result()
    }
}

/// 5a 제어 센터 토글. `SetValueIntent`(토글 값) + `LiveActivityIntent`(앱 프로세스에서 실행).
struct ToggleRestControlIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Start / Pause rest"
    static let description = IntentDescription("Start your last preset when idle, or pause an active rest.")

    @Parameter(title: "Running") var value: Bool

    init() {}
    init(value: Bool) { self.value = value }

    func perform() async throws -> some IntentResult {
        try await TimerIntentRunner.perform(.setControlRunning(value))
        return .result()
    }
}
