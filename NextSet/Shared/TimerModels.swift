import Foundation

enum TimerMode: String, Codable {
    case sets    // 세트 휴식
    case single  // 카운트다운
}

enum TimerPhase: String, Codable {
    case idle, running, paused, done, finished
}

protocol LabeledOption: CaseIterable, Hashable {
    var label: String { get }
}

/// 휴식 끝 소리. 켜면 마지막 3초 매초 작은 beep, 0초에 벨(`Sounds/rest-end.caf`).
enum AlertSound: String, Codable, LabeledOption {
    case off, on

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .on: String(localized: "On")
        }
    }
}

/// 4c "위젯 탭 동작" — 잠금화면·홈 소형 위젯을 탭했을 때.
enum WidgetTapAction: String, Codable, LabeledOption {
    case start, open

    var label: String {
        switch self {
        case .start: String(localized: "Start immediately")
        case .open: String(localized: "Open app")
        }
    }
}

enum HapticLevel: String, Codable, LabeledOption {
    case off, light, strong

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .light: String(localized: "Light")
        case .strong: String(localized: "Strong")
        }
    }
}

enum SetDot: Equatable {
    case past, current, upcoming
}

struct TimerSettings: Codable, Hashable {
    static let restRange = 5...600
    static let goalRange = 0...20
    static let presets = [30, 45, 60, 90, 120]

    var mode: TimerMode = .sets
    var restSeconds = 60
    var recentSeconds: Int?
    var goalSets = 0  // 0 = 무제한
    var sound: AlertSound = .on
    var haptic: HapticLevel = .strong
    var countdownHaptics = true
    var repeatAlert = true
    var widgetTap: WidgetTapAction = .start
    var liveActivity = true

    init() {}

    /// 키가 없어도(예전 저장값) 기본값으로 채운다 — 설정 항목을 추가해도 저장된 설정이 날아가지 않게.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? c.decodeIfPresent(TimerMode.self, forKey: .mode)) ?? .sets
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 60
        recentSeconds = try c.decodeIfPresent(Int.self, forKey: .recentSeconds)
        goalSets = try c.decodeIfPresent(Int.self, forKey: .goalSets) ?? 0
        sound = (try? c.decodeIfPresent(AlertSound.self, forKey: .sound)) ?? .on   // 예전 값 "short"/"long" → 켬
        haptic = (try? c.decodeIfPresent(HapticLevel.self, forKey: .haptic)) ?? .strong
        countdownHaptics = try c.decodeIfPresent(Bool.self, forKey: .countdownHaptics) ?? true
        repeatAlert = try c.decodeIfPresent(Bool.self, forKey: .repeatAlert) ?? true
        widgetTap = (try? c.decodeIfPresent(WidgetTapAction.self, forKey: .widgetTap)) ?? .start
        liveActivity = try c.decodeIfPresent(Bool.self, forKey: .liveActivity) ?? true
        self = validated()
    }
}

/// 시작한 기기가 알림을 예약한다. 기존 세션(nil)은 iPhone 담당으로 해석한다.
enum NotificationDevice: String, Codable {
    case phone, watch

    static var current: Self {
        #if os(watchOS)
        .watch
        #else
        .phone
        #endif
    }
}

struct TimerSession: Codable, Hashable {
    var notificationDevice: NotificationDevice?

    // Optional fields preserve decoding of sessions saved before workout history existed.
    var workoutID: UUID?
    var startedAt: Date?
    var restCount: Int?
    var historySaved: Bool?
    var phase: TimerPhase = .idle
    var completedSets = 0
    var restDuration: TimeInterval = 0     // 이번 휴식의 전체 길이 (+30 포함)
    var endDate: Date?                     // running 일 때만
    var pausedRemaining: TimeInterval = 0  // paused 일 때만
    var doneAt: Date?
    var totalRested: TimeInterval = 0
    var skippedCount = 0
}

struct WorkoutRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let mode: TimerMode
    let completedSets: Int
    let restCount: Int
    let totalRested: TimeInterval
    let skippedCount: Int
    let reachedGoal: Bool

    var averageRest: TimeInterval { totalRested / Double(max(1, restCount)) }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
