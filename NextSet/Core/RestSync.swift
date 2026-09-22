import Foundation
import OSLog
import WatchConnectivity

/// 폰↔워치 상태 동기화 (T-32). 바뀐 쪽이 설정+세션을 보내고, 받은 쪽은 더 최신이면 그대로 받아들인다.
///
/// - 즉시성: 상대가 깨어 있으면 `sendMessage`, 아니면 `updateApplicationContext`(마지막 값만 남는다)로 다음에 깨어날 때 받는다.
/// - 충돌: 각 기기의 `RestTimer.lastChangedAt`과 보낸 쪽의 `sentAt`을 비교해 더 최신 것만 적용한다.
/// - 되돌림 방지: 받아들일 때는 `RestTimer.adopt`를 써서 `stateDidChange`가 불리지 않게 한다.
final class RestSync: NSObject, WCSessionDelegate {
    private let timer: RestTimer
    private let session: WCSession?
    private let log = Logger(subsystem: "kr.co.lee.NextSet", category: "sync")

    /// 첫 종료 후 Watch 안내(6c)를 페어링된 경우에만 보여주기 위해.
    static var isWatchPaired: Bool {
        #if os(iOS)
        WCSession.isSupported() && WCSession.default.isPaired
        #else
        false
        #endif
    }

    init(timer: RestTimer) {
        self.timer = timer
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
        timer.stateDidChange = { [weak self] in self?.send() }
    }

    // MARK: - 보내기

    private func send() {
        guard let session, session.activationState == .activated else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        let payload = Self.payload(settings: timer.settings, session: timer.session, sentAt: timer.lastChangedAt,
                                   history: timer.history)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [log] error in
                log.error("sendMessage failed: \(error.localizedDescription)")
            }
        }
        do {
            try session.updateApplicationContext(payload)
            log.info("sent phase=\(self.timer.session.phase.rawValue) reachable=\(session.isReachable)")
        } catch {
            log.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    static func payload(settings: TimerSettings, session: TimerSession, sentAt: Date,
                        history: [WorkoutRecord] = []) -> [String: Any] {
        var payload: [String: Any] = ["sentAt": sentAt.timeIntervalSince1970]
        if let data = try? JSONEncoder().encode(settings) { payload["settings"] = data }
        if let data = try? JSONEncoder().encode(session) { payload["session"] = data }
        if let data = try? JSONEncoder().encode(history) { payload["history"] = data }
        return payload
    }

    // MARK: - 받기

    private func apply(_ payload: [String: Any]) {
        guard let sentAt = payload["sentAt"] as? TimeInterval,
              let settingsData = payload["settings"] as? Data,
              let sessionData = payload["session"] as? Data,
              let settings = try? JSONDecoder().decode(TimerSettings.self, from: settingsData),
              let session = try? JSONDecoder().decode(TimerSession.self, from: sessionData) else { return }
        let changedAt = Date(timeIntervalSince1970: sentAt)
        if let data = payload["history"] as? Data,
           let records = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
            timer.mergeHistory(records)
        }
        guard changedAt > timer.lastChangedAt else {
            log.info("ignored older state (sentAt \(changedAt.timeIntervalSince1970) <= local \(self.timer.lastChangedAt.timeIntervalSince1970))")
            return
        }
        log.info("adopting phase=\(session.phase.rawValue) sets=\(session.completedSets)")
        timer.adopt(settings: settings, session: session, changedAt: changedAt)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            log.info("activated state=\(activationState.rawValue) error=\(error?.localizedDescription ?? "none") contextKeys=\(context.keys.count)")
            self.apply(context)
            self.send()  // 상대가 아직 못 받은 내 상태가 있으면 보낸다
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            log.info("received message")
            self.apply(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            log.info("received applicationContext")
            self.apply(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
