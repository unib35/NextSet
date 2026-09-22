import SwiftUI
import WatchKit
import UserNotifications

/// Apple Watch 앱 진입점 (시안 4d~4f). 타이머 로직은 폰과 같은 `RestTimer`(Core/), 상태는 `RestSync`로 폰과 맞춘다.
@main
struct NextSetWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @State private var sync = RestSync(timer: .main)

    init() {
        if let seconds = TimerStore.debugAutoStartSeconds { RestTimer.main.perform(.start(seconds: seconds)) }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(RestTimer.main)
        }
    }
}

/// Watch 자체 로컬 알림의 전경 표시와 버튼 동작도 iPhone과 같은 타이머로 연결한다.
final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        RestNotifications.registerCategories()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in completionHandler([]) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        Task { @MainActor in
            RestTimer.main.handleNotificationAction(action)
            completionHandler()
        }
    }
}
