import UIKit

/// 앱이 뒤로 갈 때 휴식이 흐르고 있으면 iOS 가 허용하는 짧은 백그라운드 시간(약 30초)을 받아 둔다.
/// 그 안에 휴식이 끝나면 앱의 tick 이 직접 Live Activity·위젯을 "휴식 끝"으로 바꾼다 — 잠든 앱 대신 시스템 만료 처리를
/// 기다리면 0:00 에서 한동안 멈춰 보인다(T-93). 더 긴 휴식은 이것으로 덮지 못한다.
@MainActor
final class BackgroundGrace {
    static let shared = BackgroundGrace()
    private var task: UIBackgroundTaskIdentifier = .invalid
    private var ending: Task<Void, Never>?

    func sceneChanged(isActive: Bool, restEndsAt endDate: Date?) {
        if isActive { end(); return }
        guard let endDate, endDate > .now, task == .invalid else { return }
        task = UIApplication.shared.beginBackgroundTask(withName: "rest-end") { [weak self] in
            Task { @MainActor in self?.end() }  // 시간이 다 되면 시스템에 돌려준다
        }
        // 휴식이 끝나고 tick 이 갱신할 여유(2초)를 둔 뒤 돌려준다.
        let wait = endDate.timeIntervalSinceNow + 2
        ending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }

    private func end() {
        ending?.cancel()
        ending = nil
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
