//
//  NextSetApp.swift
//  NextSet
//
//  Created by 이종민 on 9/16/26.
//

import SwiftUI
import UIKit
import UserNotifications

@main
struct NextSetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var hints = FirstRunHints()  // 첫 실행 힌트(6c·6d)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.timer)
                .environment(hints)
        }
    }
}

/// 알림 배너의 "휴식 시작 / 운동 끝내기" 버튼은 앱이 꺼져 있어도 여기로 들어온다.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let timer = RestTimer.main
    private var sync: RestSync?

    override init() {
        super.init()
        // 폰↔워치 동기화 (T-32). UI 테스트는 `-sync.off`로 끈다 — 켜진 워치 시뮬레이터가 초기화한 상태를 덮어쓴다.
        if !ProcessInfo.processInfo.arguments.contains("-sync.off") {
            sync = RestSync(timer: timer)
        }
        // 위젯·Live Activity 버튼(LiveActivityIntent)은 시스템이 앱 프로세스에서 실행한다. 여기로 연결.
        TimerIntentRunner.handler = { action in
            RestTimer.main.perform(action)
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RestNotifications.registerCategories()
        if let seconds = TimerStore.debugAutoStartSeconds { timer.perform(.start(seconds: seconds)) }
        return true
    }

    // `async` 델리게이트 형태를 쓰면 `await` 뒤의 완료 콜백이 백그라운드 스레드에서 불리고, UIKit 이 그 안에서
    // 상태 저장(_updateStateRestorationArchive…)을 하다 메인 스레드 단언으로 죽는다(2026-09-18 알림 탭 크래시).
    // 그래서 완료 핸들러 형태로 받고, 처리와 완료 호출을 모두 메인 스레드에서 한다.

    // 앱을 보고 있을 때는 화면이 알려주므로 배너를 띄우지 않는다.
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
