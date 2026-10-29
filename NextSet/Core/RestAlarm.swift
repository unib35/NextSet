import Foundation
import Observation
import OSLog
import SwiftUI
#if os(iOS) && canImport(AlarmKit)
import AlarmKit
#endif

/// iOS 26+ 휴식 끝 알람(AlarmKit, 시안 "iOS 18 대응" A1·A2). 시스템 알람이라 무음·집중 모드에서도 울린다.
/// 앱을 보고 있을 때는 앱이 3·2·1과 벨을 내므로 `RestTimer`가 앱이 뒤로 갈 때만 요청을 넘기고, 앞으로 오면 nil 로 취소한다.
/// iOS 18·워치는 `unavailable` — 기존 로컬 알림(`RestNotifications`)을 그대로 쓴다.
@Observable
final class RestAlarm {
    @ObservationIgnored private let log = Logger(subsystem: "kr.co.lee.NextSet", category: "alarm")
    enum Authorization: Equatable { case unavailable, notDetermined, denied, authorized }

    /// 알람 한 번에 필요한 것. 같은 요청이면 다시 예약하지 않는다.
    struct Request: Equatable {
        var fireDate: Date
        var title: String
        /// 있으면 "+30초 더 쉬기" — 누르면 시스템이 30초 카운트다운 뒤 다시 울린다(`.countdown`).
        var snoozeLabel: String?
        var snoozingTitle: String
        var stopLabel: String
    }

    static let snoozeSeconds: TimeInterval = 30

    /// 실제 AlarmKit 호출을 분리해 예약·취소 순서를 결정적으로 검사한다.
    struct Backend {
        var status: () -> Authorization
        var request: () async -> Authorization
        var schedule: (UUID, Request) async throws -> Void
        var cancel: (UUID) -> Void

        static let unavailable = Backend(status: { .unavailable }, request: { .unavailable },
                                         schedule: { _, _ in }, cancel: { _ in })
    }

    private(set) var authorization: Authorization
    private(set) var schedulingFailed = false
    @ObservationIgnored private let backend: Backend
    @ObservationIgnored private var scheduled: (id: UUID, request: Request)?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private(set) var isRequestingAuthorization = false

    init(backend: Backend = .system) {
        self.backend = backend
        authorization = backend.status()
    }

    /// 설정 앱에서 권한을 바꿨을 수 있으니 앱이 앞으로 올 때 다시 읽는다.
    func refreshAuthorization() {
        authorization = backend.status()
    }

    func requestAuthorization() async {
        guard authorization == .notDetermined, !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        authorization = await backend.request()
        isRequestingAuthorization = false
    }

    /// nil 이면 취소. 앞선 예약을 항상 먼저 지우고, 늦게 끝난 예약이 새 상태를 덮지 않게 직렬로 처리한다.
    /// 휴식이 시간이 다 돼 끝나 nil 이 들어오면, 막 울리기 시작한 알람은 그대로 둔다 — 앱이 뒤에서 살아 있으면
    /// 타이머가 "휴식 끝"으로 넘어가는 순간과 알람 시각이 같아서, 지우면 울리자마자 꺼진다(T-88 시뮬레이터 로그).
    /// 앱이 앞으로 오거나 사용자가 바꾼 경우에는 `force`로 지운다.
    func sync(_ request: Request?, force: Bool = false) {
        guard request != scheduled?.request else { return }
        if request == nil, !force, let old = scheduled, old.request.fireDate <= .now.addingTimeInterval(1) { return }
        revision += 1
        let current = revision
        if let old = scheduled {
            backend.cancel(old.id)
            log.info("canceled \(old.id, privacy: .public)")
        }
        scheduled = nil
        schedulingFailed = false
        guard let request, authorization == .authorized, request.fireDate > .now else { return }
        let id = UUID()
        scheduled = (id, request)
        let previous = operation
        operation = Task {
            await previous?.value
            guard current == revision else { return }
            do {
                try await backend.schedule(id, request)
                log.info("scheduled \(id, privacy: .public) at \(request.fireDate, privacy: .public)")
                if current != revision { backend.cancel(id) }
            } catch {
                log.error("schedule failed: \(String(describing: error), privacy: .public)")
                guard current == revision else { return }
                scheduled = nil
                schedulingFailed = true
            }
        }
    }

    func waitForPendingOperations() async {
        await operation?.value
    }
}

extension RestAlarm.Backend {
    static var system: Self {
        #if os(iOS) && canImport(AlarmKit)
        if #available(iOS 26.0, *) { return .alarmKit }
        #endif
        return .unavailable
    }
}

#if os(iOS) && canImport(AlarmKit)
@available(iOS 26.0, *)
extension RestAlarm.Backend {
    static var alarmKit: Self {
        let manager = AlarmManager.shared
        func map(_ state: AlarmManager.AuthorizationState) -> RestAlarm.Authorization {
            switch state {
            case .authorized: .authorized
            case .denied: .denied
            case .notDetermined: .notDetermined
            @unknown default: .denied
            }
        }
        return Self(
            status: { map(manager.authorizationState) },
            request: { (try? await manager.requestAuthorization()).map(map) ?? .denied },
            schedule: { id, request in
                let snooze = request.snoozeLabel.map {
                    AlarmButton(text: LocalizedStringResource(stringLiteral: $0), textColor: .black, systemImageName: "plus")
                }
                let title = LocalizedStringResource(stringLiteral: request.title)
                let alert: AlarmPresentation.Alert
                if #available(iOS 26.1, *) {
                    // 26.1부터 정지 버튼은 시스템이 그린다.
                    alert = .init(title: title, secondaryButton: snooze, secondaryButtonBehavior: snooze == nil ? nil : .countdown)
                } else {
                    alert = .init(title: title,
                                  stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: request.stopLabel),
                                                          textColor: .white, systemImageName: "stop.fill"),
                                  secondaryButton: snooze, secondaryButtonBehavior: snooze == nil ? nil : .countdown)
                }
                let countdown = snooze == nil ? nil
                    : AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: request.snoozingTitle))
                let attributes = AlarmAttributes<RestAlarmMetadata>(
                    presentation: AlarmPresentation(alert: alert, countdown: countdown),
                    metadata: RestAlarmMetadata(), tintColor: .brand)
                let configuration = AlarmManager.AlarmConfiguration(
                    countdownDuration: snooze == nil ? nil : .init(preAlert: nil, postAlert: RestAlarm.snoozeSeconds),
                    schedule: .fixed(request.fireDate),
                    attributes: attributes,
                    stopIntent: RefreshRestIntent(),       // 정지 → 앱이 깨어나 Live Activity 를 "휴식 끝"으로
                    secondaryIntent: RefreshRestIntent())
                _ = try await manager.schedule(id: id, configuration: configuration)
            },
            cancel: { id in try? manager.cancel(id: id) })
    }
}
#endif
