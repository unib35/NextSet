import SwiftUI
import UIKit
import UserNotifications

/// OS 권한과 예약 실패를 앱의 소리 켜기/끄기와 구분해서 안내한다.
struct NotificationStatusView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.openURL) private var openURL
    var showsReadyState = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if timer.session.phase == .running && !timer.ownsRestAlert {
                Label(String(localized: "This rest will alert on Apple Watch."), systemImage: "applewatch")
            } else if timer.usesRestAlarm {
                // iOS 26 알람: 알림 권한과 상관없이 울린다.
                if timer.alarm.schedulingFailed {
                    Label(String(localized: "Could not set the rest alarm"), systemImage: "exclamationmark.bell")
                    Text(String(localized: "Keep the app open until rest ends, or try again."))
                } else if showsReadyState {
                    Text(String(localized: "Rest end rings as an alarm, even in Silent mode or a Focus."))
                }
            } else if timer.notifications.hasCheckedAuthorization && timer.notifications.authorization == .denied {
                Label(String(localized: "Notifications are off"), systemImage: "bell.slash")
                    .font(.subheadline.bold())
                Text(String(localized: "The timer still works. Allow notifications in Settings for alerts when you leave the app."))
                Button(String(localized: "Open notification settings")) {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .frame(minHeight: 44)
            } else if timer.notifications.schedulingFailed {
                Label(String(localized: "Could not schedule the rest alert"), systemImage: "exclamationmark.bell")
                Text(String(localized: "Keep the app open until rest ends, or try again."))
                if timer.session.phase == .running {
                    Button(String(localized: "Try again")) { timer.retryRestAlert() }
                        .frame(minHeight: 44)
                }
            } else if showsReadyState {
                Text(String(localized: "Background alerts follow your notification and Focus settings. The final 3-second cues play while the app is open."))
                if timer.alarm.authorization == .unavailable {
                    // iOS 18(시안 A5 하단 문구)
                    Text(String(localized: "In Silent mode, rest alerts only vibrate. On iOS 26 or later, they ring as an alarm."))
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(timer.isFinalCountdown ? Color.black : Color.brand)
        .task { await timer.notifications.refreshAuthorization() }
    }
}
