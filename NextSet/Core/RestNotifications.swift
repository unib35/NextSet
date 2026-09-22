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

        static var system: Self {
            let center = UNUserNotificationCenter.current()
            return Self(status: { await center.notificationSettings().authorizationStatus },
                        request: { try await center.requestAuthorization(options: [.alert, .sound]) },
                        add: { try await center.add($0) },
                        removePending: { center.removePendingNotificationRequests(withIdentifiers: $0) },
                        removeDelivered: { center.removeDeliveredNotifications(withIdentifiers: $0) })
        }
    }

    private static let category = "REST_END"
    private static let repeatInterval: TimeInterval = 30
    private static let identifiers = (0...4).map { "rest-end-\($0)" }

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var hasCheckedAuthorization = false
    private(set) var schedulingFailed = false
    let isEnabled: Bool
    @ObservationIgnored private let backend: Backend
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?

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
                let count = repeating ? Self.identifiers.count : 1
                for index in 0..<count {
                    guard current == revision else { return }
                    let content = UNMutableNotificationContent()
                    content.title = alert.title
                    content.body = alert.body
                    content.sound = Self.notificationSound(for: sound)
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

    func waitForPendingOperations() async { await pendingOperation?.value }
}
