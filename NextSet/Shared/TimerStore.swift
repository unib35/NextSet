import Foundation

/// 앱·위젯·(나중에) Live Activity 가 같은 상태를 읽고 쓰는 저장소.
///
/// App Group 공유 `UserDefaults`를 쓴다. 위젯 익스텐션은 별도 프로세스라 `.standard`로는 앱 상태를 볼 수 없다.
/// 두 타깃 모두 `NextSet.entitlements` / `NextSetWidgets.entitlements`에 같은 App Group 이 들어 있어야 한다.
enum TimerStore {
    static let appGroup = "group.kr.co.lee.NextSet"

    enum Keys {
        static let settings = "timer.settings"
        static let session = "timer.session"
        static let changedAt = "timer.changedAt"  // 마지막 변경 시각 (폰↔워치 동기화의 최신 판정)
        static let history = "timer.history"
        static let hiddenHistory = "timer.hiddenHistory"
        static let endedWorkouts = "stats.endedWorkouts"   // 저장된 운동 기록 수 누적 (첫 실행 힌트 시점 판단)
        static let hintLockScreen = "hints.lockScreen"     // 6c 첫 휴식 중 잠금화면 힌트 봤음
        static let hintWatch = "hints.watch"               // 6c 첫 종료 후 Watch 안내 봤음
        static let hintWidgetGuide = "hints.widgetGuide"   // 6d 두 번째 종료 후 위젯 안내 봤음
        static let all = [settings, session, changedAt, history, hiddenHistory, endedWorkouts, hintLockScreen, hintWatch, hintWidgetGuide]
    }

    /// 공유 저장소. App Group 을 못 열면(엔타이틀먼트 누락) `.standard`로 물러난다 — 이 경우 위젯은 상태를 못 본다.
    /// 처음 접근할 때 예전 `.standard`에 남아 있던 값을 한 번 옮긴다 (T-21 이전 설치분 호환).
    static let shared: UserDefaults = {
        guard let group = UserDefaults(suiteName: appGroup) else { return .standard }
        migrate(from: .standard, to: group)
        #if DEBUG
        // UI 테스트용 초기화. 실행 인자 도메인(`-timer.session -`)은 `.standard`에만 적용되고
        // App Group suite 에는 먹지 않아서, 직접 지운다.
        if ProcessInfo.processInfo.arguments.contains(resetArgument) {
            Keys.all.forEach { group.removeObject(forKey: $0) }
        }
        #endif
        return group
    }()

    /// `xcrun simctl launch … -timer.reset` / UI 테스트 `launchArguments` — 저장된 상태 없이 시작한다 (DEBUG 전용).
    static let resetArgument = "-timer.reset"

    /// `-timer.start N` — 실행 직후 N초 휴식을 시작한다 (DEBUG 전용). 워치 시뮬레이터는 CLI 로 탭할 수 없어서 넣었다.
    static var debugAutoStartSeconds: Int? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-timer.start"), index + 1 < args.count else { return nil }
        return Int(args[index + 1])
        #else
        return nil
        #endif
    }

    /// `to`에 아직 아무 값도 없을 때만 `from`의 값을 복사한다. 옮긴 뒤 원본은 지운다.
    static func migrate(from source: UserDefaults, to target: UserDefaults) {
        guard Keys.all.allSatisfy({ target.object(forKey: $0) == nil }) else { return }
        for key in Keys.all {
            if let value = source.object(forKey: key) {
                target.set(value, forKey: key)
                source.removeObject(forKey: key)
            }
        }
    }

    static func save<Value: Encodable>(_ value: Value, forKey key: String, to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    static func load<Value: Decodable>(_ type: Value.Type, forKey key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func loadSettings(from defaults: UserDefaults = shared) -> TimerSettings {
        (load(TimerSettings.self, forKey: Keys.settings, from: defaults) ?? TimerSettings()).validated()
    }

    static func loadSession(from defaults: UserDefaults = shared) -> TimerSession {
        (load(TimerSession.self, forKey: Keys.session, from: defaults) ?? TimerSession()).validated()
    }

    static func loadHistory(from defaults: UserDefaults = shared) -> [WorkoutRecord] {
        (load([WorkoutRecord].self, forKey: Keys.history, from: defaults) ?? []).filter(\.isValid)
    }
}
