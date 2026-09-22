import Foundation
import Observation
import WidgetKit

/// 앱 전체가 공유하는 휴식 타이머 상태.
/// 남은 시간은 매 틱 깎지 않고 `endDate` 기준으로 계산하므로 백그라운드에 다녀와도 정확하다.
@Observable
final class RestTimer {
    /// 카운트다운 모드의 완료 화면(✓)만 이 시간 뒤에 대기로 돌아간다. 세트 모드의 휴식 끝 화면(3c)은 탭할 때까지 유지 (2026-09-18 결정).
    static let doneScreenDuration: TimeInterval = 3.0

    /// 앱이 쓰는 단 하나의 인스턴스. 위젯·Live Activity 버튼(AppIntent)도 여기로 들어온다.
    static let main = RestTimer()

    /// 이 기기에서 저장한 운동 기록 수(삭제와 무관하게 누적). 첫 실행 힌트(6c·6d)의 표시 시점 판단에 쓴다.
    @ObservationIgnored private(set) var endedWorkoutCount: Int {
        didSet { defaults.set(endedWorkoutCount, forKey: TimerStore.Keys.endedWorkouts) }
    }

    /// 이 기기에서 상태가 바뀌었을 때 (다른 기기에서 받은 변경은 제외). `RestSync`가 폰↔워치 전송에 쓴다.
    @ObservationIgnored var stateDidChange: (() -> Void)?
    /// 마지막으로 상태가 바뀐 시각. 동기화에서 더 최신 쪽을 고르는 기준. 저장소에 같이 남긴다.
    @ObservationIgnored private(set) var lastChangedAt: Date {
        didSet { defaults.set(lastChangedAt.timeIntervalSince1970, forKey: TimerStore.Keys.changedAt) }
    }
    @ObservationIgnored private var isAdopting = false
    /// 시간이 흘러서 생기는 전환(휴식 끝, 1.8초 뒤 대기 복귀)은 상대 기기도 같은 세션으로 똑같이 계산하므로
    /// "내가 바꾼 것"으로 치지 않는다 — 시각을 올리거나 보내면 상대의 방금 조작을 덮어쓸 수 있다.
    @ObservationIgnored private var isSystemTransition = false

    var settings: TimerSettings {
        didSet {
            TimerStore.save(settings, forKey: TimerStore.Keys.settings, to: defaults)
            // 설정 시트에서 소리를 바꾸면 바로 들려준다.
            if settings.sound != oldValue.sound, !isAdopting { feedback.preview(settings.sound) }
            if settings.haptic != oldValue.haptic, !isAdopting { feedback.previewHaptic(settings.haptic) }
            if settings.liveActivity != oldValue.liveActivity {
                liveActivity.sync(settings: settings, session: session)
            }
            if !isAdopting, session.phase == .running,
               settings.sound != oldValue.sound || settings.repeatAlert != oldValue.repeatAlert {
                scheduleRestEndAlert()
            }
            // 스테퍼를 연타해도 위젯 갱신은 한 번만.
            scheduleWidgetReload(after: .milliseconds(500))
            markChanged()
        }
    }
    private(set) var session: TimerSession {
        didSet {
            TimerStore.save(session, forKey: TimerStore.Keys.session, to: defaults)
            scheduleWidgetReload(after: .zero)
            liveActivity.sync(settings: settings, session: session)
            markChanged()
        }
    }
    private(set) var now: Date
    private(set) var toast: String?
    private(set) var history: [WorkoutRecord] {
        didSet { TimerStore.save(history, forKey: TimerStore.Keys.history, to: defaults) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    let notifications: RestNotifications
    @ObservationIgnored private let notificationDevice: NotificationDevice
    @ObservationIgnored private let liveActivity: RestActivityController
    @ObservationIgnored private let feedback = RestFeedback()
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var widgetReloadTask: Task<Void, Never>?
    @ObservationIgnored private var lastCountdownSecond: Int?
    @ObservationIgnored private var isInForeground = false
    @ObservationIgnored private var hiddenHistory: Set<UUID>

    /// 기본 저장소는 App Group 공유 `UserDefaults`(위젯과 공유). 테스트는 임시 suite 를 넣는다.
    init(defaults: UserDefaults = TimerStore.shared,
         notifications: RestNotifications = RestNotifications(),
         liveActivity: RestActivityController = RestActivityController(),
         clock: @escaping () -> Date = { .now },
         notificationDevice: NotificationDevice = .current) {
        self.defaults = defaults
        self.notifications = notifications
        self.notificationDevice = notificationDevice
        self.liveActivity = liveActivity
        self.clock = clock
        settings = TimerStore.loadSettings(from: defaults)
        session = TimerStore.loadSession(from: defaults)
        history = Array(TimerStore.loadHistory(from: defaults).sorted { $0.endedAt > $1.endedAt }.prefix(30))
        hiddenHistory = TimerStore.load(Set<UUID>.self, forKey: TimerStore.Keys.hiddenHistory, from: defaults) ?? []
        now = clock()
        let stored = defaults.object(forKey: TimerStore.Keys.changedAt) as? TimeInterval
        lastChangedAt = stored.map { Date(timeIntervalSince1970: $0) } ?? .distantPast
        endedWorkoutCount = defaults.integer(forKey: TimerStore.Keys.endedWorkouts).clamped(to: 0...TimerValidation.maxCount)
        tick()
    }

    // MARK: - 파생 값 (위젯과 같은 계산 → `TimerSnapshot`)

    private var snapshot: TimerSnapshot { TimerSnapshot(settings: settings, session: session) }

    var isActive: Bool { snapshot.isActive }
    var remaining: TimeInterval { snapshot.remaining(at: now) }

    var displaySeconds: Int {
        isActive ? TimerValidation.seconds(remaining) : settings.restSeconds
    }

    var progress: Double {
        guard isActive, session.restDuration > 0 else { return 1 }
        return min(1, remaining / session.restDuration)
    }

    /// 마지막 3초: 숫자가 흰색으로 커지고 매초 햅틱.
    var isFinalCountdown: Bool {
        session.phase == .running && settings.countdownHaptics && remaining <= 3
    }

    /// 마지막 3초 중 몇 번째 초인지 (0, 1, 2).
    var countdownStep: Int {
        (3 - TimerValidation.seconds(remaining)).clamped(to: 0...2)
    }

    var hasGoal: Bool { snapshot.hasGoal }
    var nextSetNumber: Int { snapshot.nextSetNumber }
    /// 대기(3a)와 휴식 끝(3c) 화면에서 운동을 끝낼 수 있다. 휴식 끝 화면은 탭할 때까지 유지되므로 여기서도 출구가 필요하다.
    var canEndWorkout: Bool {
        (session.phase == .idle || session.phase == .done) && (session.workoutID != nil || session.completedSets > 0)
    }
    var averageRest: TimeInterval { session.totalRested / Double(max(1, session.completedSets)) }
    var dots: [SetDot] { snapshot.dots }
    var setCaption: String { snapshot.setCaption }

    var startLabel: String {
        if settings.mode == .single { return String(localized: "Start") }
        return session.completedSets == 0 ? String(localized: "Set done → Rest") : String(localized: "Start rest")
    }

    var goalLabel: String {
        settings.goalSets > 0 ? String(localized: "\(settings.goalSets) sets") : String(localized: "Unlimited")
    }

    // MARK: - 조작

    func start() {
        tick()
        guard !isActive else { return }
        if session.phase == .finished || (settings.mode == .single && session.historySaved == true) {
            archiveWorkout()
            session = TimerSession()
        }
        let duration = TimeInterval(settings.restSeconds)
        var next = session
        if next.workoutID == nil {
            next.workoutID = UUID()
            next.startedAt = now
        }
        next.phase = .running
        next.notificationDevice = notificationDevice
        next.restDuration = duration
        next.endDate = now.addingTimeInterval(duration)
        next.doneAt = nil
        session = next
        settings.recentSeconds = settings.restSeconds
        lastCountdownSecond = nil
        scheduleRestEndAlert()
        updateTicker()
    }

    func togglePause() {
        tick()
        switch session.phase {
        case .running:
            var next = session
            next.pausedRemaining = remaining
            next.endDate = nil
            next.phase = .paused
            session = next
            notifications.cancelPending()
            feedback.pauseToggled(isPaused: true, level: settings.haptic)
        case .paused:
            var next = session
            next.endDate = now.addingTimeInterval(session.pausedRemaining)
            next.phase = .running
            session = next
            scheduleRestEndAlert()
            feedback.pauseToggled(isPaused: false, level: settings.haptic)
        default:
            return
        }
        updateTicker()
    }

    func addThirtySeconds() { adjustRemaining(by: 30) }

    /// 진행 중인 휴식에 초를 더하거나 뺀다 (−10 / +10 / +30). 남은 시간은 1초 밑으로 내려가지 않는다.
    /// 다음 휴식 길이(`settings.restSeconds`)는 건드리지 않는다 → `docs/DECISIONS.md` "+30".
    func adjustRemaining(by seconds: Int) {
        tick()
        guard isActive, (-600...600).contains(seconds) else { return }
        let delta = min(max(TimeInterval(seconds), 1 - remaining),
                        TimerValidation.maxRest - session.restDuration)
        var next = session
        if next.phase == .running {
            next.endDate = next.endDate?.addingTimeInterval(delta)
        } else {
            next.pausedRemaining += delta
        }
        next.restDuration = max(1, next.restDuration + delta)
        session = next
        if session.phase == .running { scheduleRestEndAlert() }
        lastCountdownSecond = nil
    }

    /// 이 휴식을 처음부터 다시 (워치 4e 메뉴 "이 휴식 다시 시작"). 세트 수는 그대로.
    func restartRest() {
        tick()
        guard isActive else { return }
        let duration = TimeInterval(settings.restSeconds)
        var next = session
        next.totalRested += max(0, session.restDuration - remaining)
        next.phase = .running
        next.notificationDevice = notificationDevice
        next.restDuration = duration
        next.endDate = now.addingTimeInterval(duration)
        next.pausedRemaining = 0
        session = next
        lastCountdownSecond = nil
        scheduleRestEndAlert()
        updateTicker()
    }

    func skip() {
        tick()
        guard isActive else { return }
        finishRest(skipped: true, at: now)
        notifications.cancelPending()
        updateTicker()
    }

    /// 진행 중 휴식까지 기록한 뒤 세션을 정리한다. 첫 휴식 중 종료도 저장한다.
    /// ✕ / 알림·위젯의 "운동 끝내기".
    /// 세트가 하나라도 있으면 완료 요약(3d)으로 간다(목표 세트가 없어도 — 2026-09-18 결정). 요약의 "끝내기"는 여기로 다시 들어와 초기화한다.
    /// 세트가 없으면 요약 없이 초기화하고, 쉰 시간이 있으면 토스트로만 알린다.
    func endWorkout() {
        tick()
        if session.phase == .finished {
            archiveWorkout()
            resetSession()
            return
        }
        let rested = session.totalRested + (isActive ? session.restDuration - remaining : 0)
        archiveWorkout()
        if session.completedSets > 0 {
            var next = session
            next.totalRested = rested
            next.endDate = nil
            next.pausedRemaining = 0
            next.doneAt = nil
            next.phase = .finished
            session = next
            notifications.cancelPending()
            lastCountdownSecond = nil
            updateTicker()
        } else {
            resetSession()
            if rested > 0 { showToast(String(localized: "Rest \(Self.format(rested)) · Saved")) }
        }
    }

    /// 완료 요약의 "한 번 더" — 첫 세트부터 다시.
    func startOver() {
        tick()
        archiveWorkout()
        resetSession()
    }

    func setRestSeconds(_ seconds: Int) {
        guard !isActive else { return }
        settings.restSeconds = seconds.clamped(to: TimerSettings.restRange)
    }

    func adjustRestSeconds(by delta: Int) {
        setRestSeconds(settings.restSeconds + delta.clamped(to: -600...600))
    }

    func adjustGoal(by delta: Int) {
        // 무제한(0)에서 + 를 누르면 2세트부터 시작한다.
        let delta = delta.clamped(to: -20...20)
        let goal = delta > 0 ? max(settings.goalSets, 1) + delta : settings.goalSets + delta
        settings.goalSets = goal.clamped(to: TimerSettings.goalRange)
    }

    func selectMode(_ mode: TimerMode) {
        guard mode != settings.mode, !isActive else { return }
        archiveWorkout()
        settings.mode = mode
        resetSession()
    }

    /// 위젯·Live Activity·제어 센터 버튼(AppIntent)과 딥링크가 모두 여기로 들어온다 (로직은 이 한 곳).
    /// `start`는 대기 중일 때만 — 실행 중 재탭은 무시. 나머지는 각 메서드의 조건을 따른다.
    func perform(_ action: TimerAction) {
        tick()
        switch action {
        case .start(let seconds):
            guard !isActive else { return }
            setRestSeconds(seconds ?? snapshot.lastPresetSeconds)
            start()
        case .togglePause: togglePause()
        case .add(let seconds): adjustRemaining(by: seconds)
        case .restartRest: restartRest()
        case .skip: skip()
        case .endWorkout: endWorkout()
        case .startOver: startOver()
        case .setControlRunning(let shouldRun):
            if shouldRun {
                if session.phase == .paused { togglePause() }
                else if !isActive { perform(.start(seconds: nil)) }
            } else if session.phase == .running { togglePause() }
        case .controlToggle:
            if isActive { togglePause() } else { perform(.start(seconds: nil)) }
        }
    }

    /// 위젯 탭 딥링크 (`nextset://start[?seconds=N]`, `toggle`, `plus30`, `add?seconds=N`, `skip`). 그 밖의 URL(`nextset://open`)은 앱만 연다.
    func handleURL(_ url: URL) {
        guard url.scheme == "nextset" else { return }
        switch url.host() {
        case "start":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            perform(.start(seconds: query?.first { $0.name == "seconds" }?.value.flatMap(Int.init)))
        case "toggle": perform(.togglePause)
        case "plus30": perform(.add(seconds: 30))
        case "add":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            perform(.add(seconds: query?.first { $0.name == "seconds" }?.value.flatMap(Int.init) ?? 30))
        case "skip": perform(.skip)
        default: tick()
        }
    }

    /// 다른 기기(폰↔워치)에서 온 상태를 그대로 받아들인다. `stateDidChange`는 부르지 않는다(되돌려 보내지 않기 위해).
    /// 시작한 기기만 알림을 예약하며, 다른 기기는 이전 예약을 취소한다.
    func adopt(settings: TimerSettings, session: TimerSession, changedAt: Date) {
        guard changedAt.timeIntervalSince1970.isFinite else { return }
        isAdopting = true
        self.settings = settings.validated()
        self.session = session.validated()
        isAdopting = false
        lastChangedAt = changedAt
        lastCountdownSecond = nil
        if self.session.phase == .running { scheduleRestEndAlert() } else { notifications.cancelPending() }
        tick()
    }

    private func markChanged() {
        guard !isAdopting, !isSystemTransition else { return }
        lastChangedAt = clock()
        stateDidChange?()
    }

    func handleNotificationAction(_ identifier: String) {
        switch identifier {
        case RestNotifications.Action.startRest: start()
        case RestNotifications.Action.endWorkout: endWorkout()
        default: tick()
        }
    }

    func scenePhaseChanged(isActive: Bool) {
        isInForeground = isActive
        guard isActive else { return }
        tick()
        // 앱을 열었으면 반응한 것으로 보고 쌓인 알림과 반복 알림을 정리한다.
        notifications.removeDelivered()
        if session.phase == .running { scheduleRestEndAlert() } else { notifications.cancelPending() }
        Task { await notifications.refreshAuthorization() }
    }

    // MARK: - 진행

    func tick() {
        now = clock()
        isSystemTransition = true
        defer { isSystemTransition = false }
        if session.phase == .running, let endDate = session.endDate {
            if endDate <= now {
                finishRest(skipped: false, at: endDate)
            } else {
                playCountdownIfNeeded()
            }
        }
        if session.phase == .done, settings.mode == .single, let doneAt = session.doneAt,
           now.timeIntervalSince(doneAt) >= Self.doneScreenDuration {
            session.phase = .idle
            session.doneAt = nil
        }
        updateTicker()
    }

    /// 휴식 끝 화면(3c)에서 "시간 바꾸기" — 휴식을 시작하지 않고 대기 화면(3a)으로. 세트 수는 그대로.
    func goToSetup() {
        tick()
        guard session.phase == .done else { return }
        var next = session
        next.phase = .idle
        next.doneAt = nil
        session = next
        updateTicker()
    }

    private func finishRest(skipped: Bool, at date: Date) {
        let isLive = isInForeground && now.timeIntervalSince(date) < 1.5
        var next = session
        next.totalRested += max(0, session.restDuration - (skipped ? remaining : 0))
        if skipped { next.skippedCount += 1 }
        if settings.mode == .sets { next.completedSets += 1 }
        next.restCount = (session.restCount ?? session.completedSets) + 1
        next.endDate = nil
        next.pausedRemaining = 0
        next.doneAt = date
        next.phase = hasGoal && next.completedSets >= settings.goalSets ? .finished : .done
        session = next
        if next.phase == .finished || settings.mode == .single { archiveWorkout(endedAt: date) }
        lastCountdownSecond = nil

        if !skipped && isLive {
            feedback.restEnded(haptic: settings.haptic, sound: settings.sound)
            notifications.cancelPending()  // 화면을 보고 있었으니 반복 알림은 필요 없다
        }
    }

    private func playCountdownIfNeeded() {
        guard isFinalCountdown else {
            lastCountdownSecond = nil
            return
        }
        let second = TimerValidation.seconds(remaining)
        guard second != lastCountdownSecond else { return }
        lastCountdownSecond = second
        if isInForeground { feedback.countdownTick(settings.haptic, sound: settings.sound) }
    }

    private func resetSession() {
        notifications.cancelPending()
        notifications.removeDelivered()
        session = TimerSession()
        lastCountdownSecond = nil
        updateTicker()
    }

    // MARK: - 최근 운동 (기기 내 최근 30회)

    private func archiveWorkout(endedAt: Date? = nil) {
        guard session.historySaved != true,
              let id = session.workoutID, let startedAt = session.startedAt else { return }
        let partial = isActive ? max(0, session.restDuration - remaining) : 0
        let record = WorkoutRecord(id: id, startedAt: startedAt, endedAt: endedAt ?? now,
                                   mode: settings.mode, completedSets: session.completedSets,
                                   restCount: (session.restCount ?? session.completedSets) + (isActive ? 1 : 0),
                                   totalRested: session.totalRested + partial,
                                   skippedCount: session.skippedCount,
                                   reachedGoal: session.phase == .finished)
        // Save before marking the session. Retrying after interruption cannot duplicate a record.
        if !hiddenHistory.contains(id), !history.contains(where: { $0.id == id }) {
            history = Array(([record] + history).sorted { $0.endedAt > $1.endedAt }.prefix(30))
            endedWorkoutCount = min(endedWorkoutCount + 1, TimerValidation.maxCount)
        }
        session.historySaved = true
    }

    func deleteHistory(at offsets: IndexSet) {
        hiddenHistory.formUnion(history.enumerated().filter { offsets.contains($0.offset) }.map { $0.element.id })
        TimerStore.save(hiddenHistory, forKey: TimerStore.Keys.hiddenHistory, to: defaults)
        history = history.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    /// Paired devices may deliver old payloads repeatedly. IDs also preserve local deletions.
    func mergeHistory(_ records: [WorkoutRecord]) {
        var combined = Dictionary(history.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for record in records where !hiddenHistory.contains(record.id) {
            guard record.isValid else { continue }
            if combined[record.id] == nil { combined[record.id] = record }
        }
        history = Array(combined.values.sorted { $0.endedAt > $1.endedAt }.prefix(30))
    }

    private func updateTicker() {
        let needsTicks = session.phase == .running || (session.phase == .done && settings.mode == .single)
        if !needsTicks {
            ticker?.cancel()
            ticker = nil
        } else if ticker == nil {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self else { return }
                    self.tick()
                }
            }
        }
    }

    var ownsRestAlert: Bool { (session.notificationDevice ?? .phone) == notificationDevice }

    func retryRestAlert() {
        if session.phase == .running { scheduleRestEndAlert() }
    }

    private func scheduleRestEndAlert() {
        guard ownsRestAlert else {
            notifications.cancelPending()
            return
        }
        guard let endDate = session.endDate else { return }
        let alert: RestNotifications.Alert
        if settings.mode == .single {
            alert = .init(title: String(localized: "Countdown complete"), body: String(localized: "Your timer has finished."), isActionable: false)
        } else if hasGoal && session.completedSets + 1 >= settings.goalSets {
            alert = .init(title: String(localized: "Workout complete"), body: String(localized: "Goal reached: \(settings.goalSets) sets · View summary"), isActionable: false)
        } else {
            alert = .init(title: String(localized: "Rest over"), body: String(localized: "Time to start set \(session.completedSets + 2)"), isActionable: true)
        }
        notifications.schedule(alert, at: endDate,
                               sound: settings.sound,
                               repeating: alert.isActionable && settings.repeatAlert)
    }

    private func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - 위젯

    /// 저장된 상태가 바뀌었으니 위젯 타임라인을 다시 그리게 한다.
    private func scheduleWidgetReload(after delay: Duration) {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            #if os(iOS)
            ControlCenter.shared.reloadAllControls()
            #endif
        }
    }

    // MARK: - 포맷

    static func format(_ interval: TimeInterval) -> String {
        let total = TimerValidation.seconds(interval)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
