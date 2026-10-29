import Foundation
import Observation
import UserNotifications

/// 권한 확인과 예약을 직렬 처리해 취소/시간 변경보다 오래된 비동기 결과가 알림을 되살리지 않게 한다.
@Observable
final class RestNotifications {
    struct Alert {
        let title: String
        let body: String
        let isActionable: Bool
    }

    enum Action {
        static let startRest = "START_REST"
        static let endWorkout = "END_WORKOUT"
    }

    /// 실제 OS 호출을 분리해 최초 권한 응답·예약 도중 취소도 결정적으로 검사한다.
    struct Backend {
        var status: () async -> UNAuthorizationStatus
        var request: () async throws -> Bool
        var add: (UNNotificationRequest) async throws -> Void
        var removePending: ([String]) -> Void
        var removeDelivered: ([String]) -> Void
        /// 이 앱의 시간 민감 알림 설정(사용자가 설정 앱에서 끌 수 있다). 바꿀 수는 없고 읽기만 한다.
        var timeSensitive: () async -> UNNotificationSetting = { .notSupported }

        static var system: Self {
            let center = UNUserNotificationCenter.current()
            return Self(status: { await center.notificationSettings().authorizationStatus },
                        request: { try await center.requestAuthorization(options: [.alert, .sound]) },
                        add: { try await center.add($0) },
                        removePending: { center.removePendingNotificationRequests(withIdentifiers: $0) },
                        removeDelivered: { center.removeDeliveredNotifications(withIdentifiers: $0) },
                        timeSensitive: { await center.notificationSettings().timeSensitiveSetting })
        }
    }

    nonisolated static let workoutReminderIdentifier = "workout-inactivity"
    private static let category = "REST_END"
    private static let repeatInterval: TimeInterval = 30
    // 이전 버전의 추가 4회 예약도 취소/정리할 수 있도록 전체 식별자는 유지한다.
    private static let identifiers = (0...4).map { "rest-end-\($0)" }

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var hasCheckedAuthorization = false
    private(set) var timeSensitive: UNNotificationSetting = .notSupported
    private(set) var schedulingFailed = false
    let isEnabled: Bool
    @ObservationIgnored private let backend: Backend
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?

    @ObservationIgnored private var reminderRevision = 0
    @ObservationIgnored private var reminderOperation: Task<Void, Never>?

    init(isEnabled: Bool = true, backend: Backend = .system) {
        self.isEnabled = isEnabled
        self.backend = backend
    }

    static func registerCategories() {
        let start = UNNotificationAction(identifier: Action.startRest, title: String(localized: "Start rest"))
        let end = UNNotificationAction(identifier: Action.endWorkout, title: String(localized: "End workout"), options: .destructive)
        let category = UNNotificationCategory(identifier: category, actions: [start, end], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func refreshAuthorization() async {
        guard isEnabled else { return }
        authorization = await backend.status()
        timeSensitive = await backend.timeSensitive()
        hasCheckedAuthorization = true
    }

    func schedule(_ alert: Alert, at date: Date, sound: AlertSound, repeating: Bool) {
        guard isEnabled else { return }
        revision += 1
        let current = revision
        schedulingFailed = false
        backend.removePending(Self.identifiers)
        let previous = pendingOperation
        pendingOperation = Task {
            await previous?.value
            guard current == revision else { return }
            // 이전 add가 취소 요청 후 완료됐을 수도 있으므로 새 예약 전에 다시 정리한다.
            backend.removePending(Self.identifiers)
            do {
                await refreshAuthorization()
                guard current == revision else { return }
                if authorization == .notDetermined {
                    _ = try await backend.request()
                    await refreshAuthorization()
                }
                guard current == revision else { return }
                #if os(iOS)
                let canNotify = authorization == .authorized || authorization == .provisional || authorization == .ephemeral
                #else
                let canNotify = authorization == .authorized || authorization == .provisional
                #endif
                guard canNotify else { return }
                // 권한 대화상자를 오래 열어 둔 경우 이미 끝난 휴식을 뒤늦게 알리지 않는다.
                guard date > .now else { return }
                let count = repeating ? 2 : 1
                for index in 0..<count {
                    guard current == revision else { return }
                    let content = UNMutableNotificationContent()
                    content.title = alert.title
                    content.body = alert.body
                    content.sound = Self.notificationSound(for: sound)
                    // 시안 A4: 휴식 끝은 시간 민감 알림 — 요약에 묶이지 않고, 시간 민감을 허용한 집중 모드도 뚫는다.
                    content.interruptionLevel = .timeSensitive
                    if alert.isActionable { content.categoryIdentifier = Self.category }
                    let fireDate = date.addingTimeInterval(Double(index) * Self.repeatInterval)
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false)
                    try await backend.add(UNNotificationRequest(identifier: Self.identifiers[index], content: content, trigger: trigger))
                    if current != revision {
                        backend.removePending(Self.identifiers)
                        return
                    }
                }
            } catch {
                guard current == revision else { return }
                backend.removePending(Self.identifiers)
                schedulingFailed = true
            }
        }
    }

    private static func notificationSound(for sound: AlertSound) -> UNNotificationSound? {
        guard let fileName = sound.fileName else { return nil }
        #if os(watchOS)
        return .default
        #else
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
        #endif
    }

    func cancelPending() {
        guard isEnabled else { return }
        revision += 1
        schedulingFailed = false
        backend.removePending(Self.identifiers)
        let previous = pendingOperation
        pendingOperation = Task {
            await previous?.value
            backend.removePending(Self.identifiers)
        }
    }

    func removeDelivered() {
        guard isEnabled else { return }
        backend.removeDelivered(Self.identifiers)
    }

    /// 휴식 끝 반복 예약과 별개의 한 번짜리 운동 확인 알림. 취소/진행 갱신도 직렬 처리한다.
    func scheduleWorkoutReminder(at date: Date?, sound: AlertSound) {
        guard isEnabled else { return }
        reminderRevision += 1
        let current = reminderRevision
        let ids = [Self.workoutReminderIdentifier]
        backend.removePending(ids)
        backend.removeDelivered(ids)
        let previous = reminderOperation
        let restPermission = pendingOperation
        reminderOperation = Task {
            await previous?.value
            await restPermission?.value
            guard current == reminderRevision else { return }
            backend.removePending(ids)
            guard let date, date > .now else { return }
            // 휴식 알림의 권한 요청이 끝난 뒤 확인. 별도의 권한 팝업을 추가하지 않는다.
            let status = await backend.status()
            guard current == reminderRevision else { return }
            #if os(iOS)
            let allowed = status == .authorized || status == .provisional || status == .ephemeral
            #else
            let allowed = status == .authorized || status == .provisional
            #endif
            guard allowed else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Have you finished your workout?")
            content.body = String(localized: "No sets completed for an hour. Open the app to finish or continue your workout.")
            content.sound = Self.notificationSound(for: sound)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            do {
                try await backend.add(UNNotificationRequest(identifier: Self.workoutReminderIdentifier, content: content, trigger: trigger))
                if current != reminderRevision { backend.removePending(ids) }
            } catch {
                // 휴식 종료 알림의 예약 상태와 독립적으로 처리한다.
                backend.removePending(ids)
            }
        }
    }

    func waitForPendingOperations() async {
        await pendingOperation?.value
        await reminderOperation?.value
    }
}
