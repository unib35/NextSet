import SwiftUI
import WatchKit
import UserNotifications

/// 워치 화면 크기별 치수. 40mm(162×197pt)부터 49mm(205×251pt)까지 한 레이아웃으로 맞춘다.
/// 시안(230×276 프레임)의 비율: 큰 숫자 92~100px ≈ 높이의 1/3, 알약 38px, 좌우 여백 22px.
enum WatchMetrics {
    static var screen: CGSize { WKInterfaceDevice.current().screenBounds.size }
    /// 큰 숫자 폰트. 40mm ~71, 42mm ~80, 49mm ~88.
    static var bigNumber: CGFloat { min(88, (screen.height * 0.36).rounded()) }
    static var pillHeight: CGFloat { screen.height < 210 ? 36 : 40 }
    static var horizontalPadding: CGFloat { screen.width < 180 ? 4 : 8 }
    /// 알약 버튼을 화면 맨 아래에 붙일 때 둥근 모서리에서 띄우는 여백.
    static var bottomPadding: CGFloat { screen.height < 210 ? 6 : 8 }
}

/// phase 에 따라 4d(대기) / 4e(휴식 중) / 4f(휴식 끝·완료) 를 보여준다.
struct WatchContentView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsNotificationHelp = false

    /// 시안의 맨 윗줄(왼쪽 제목 · 오른쪽 시계)은 watchOS 의 툴바 자리다.
    private var title: String {
        switch timer.session.phase {
        case .idle: String(localized: "NextSet")
        case .running: String(localized: "Rest")
        case .paused: String(localized: "Paused")
        case .done: String(localized: "Rest over")
        case .finished: String(localized: "Finished")
        }
    }

    private var isOrangeScreen: Bool { timer.session.phase == .done || timer.session.phase == .finished }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch timer.session.phase {
                case .idle: WatchSetupView()
                case .running, .paused: WatchRunningView()
                case .done, .finished: WatchDoneView()
                }
            }
            .navigationTitle("")  // 제목은 아래 topBarLeading 에 직접 그린다 (기본 타이틀은 시계 아래 오른쪽에 붙어 한 줄을 더 쓴다)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if timer.notifications.authorization == .denied || timer.notifications.schedulingFailed {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showsNotificationHelp = true } label: {
                            Image(systemName: "bell.slash")
                        }
                        .accessibilityLabel(String(localized: "Check notification settings"))
                    }
                }
                // 시안의 맨 윗줄: 왼쪽 오렌지 제목, 오른쪽 시계.
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOrangeScreen ? Color.black : Color.brand)
                        .padding(.leading, 4)
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .alert(String(localized: "Check notification settings"), isPresented: $showsNotificationHelp) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Allow NextSet notifications in your notification settings. Keep the app open if an alert could not be scheduled."))
        }
        .onChange(of: timer.notifications.authorization) { _, status in
            if status == .denied && timer.session.phase == .running && timer.ownsRestAlert { showsNotificationHelp = true }
        }
        .onChange(of: timer.notifications.schedulingFailed) { _, failed in
            if failed { showsNotificationHelp = true }
        }
        .animation(.easeInOut(duration: 0.25), value: timer.session.phase)
        .onChange(of: scenePhase, initial: true) { _, phase in
            timer.scenePhaseChanged(isActive: phase == .active)
        }
        .onOpenURL { url in
            timer.handleURL(url)  // 컴플리케이션 탭 → nextset://start
        }
    }
}

/// 큰 숫자. Button 으로 감싸면 watchOS 가 라벨을 잘라내므로(42mm 에서 확인) 탭 제스처만 쓴다.
/// 자간(tracking)은 마지막 글자가 잘리는 SwiftUI 문제 때문에 쓰지 않는다 (`docs/DECISIONS.md`).
struct WatchBigNumber: View {
    let text: String
    var color: Color = .brand
    var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: WatchMetrics.bigNumber * scale, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: WatchMetrics.bigNumber * scale * 0.9)  // 시안 line-height .9 — 아래 캡션이 숫자에 붙는다
            .layoutPriority(1)
    }
}

/// 세트 점 (폰 `SetDots`와 같은 뜻).
struct WatchSetDots: View {
    let dots: [SetDot]
    var onOrange = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(dots.indices, id: \.self) { index in
                Circle()
                    .fill(color(dots[index]))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: dots)
    }

    private func color(_ dot: SetDot) -> Color {
        switch dot {
        case .past: onOrange ? .black : .brand
        case .current: onOrange ? .black.opacity(0.45) : .white
        case .upcoming: onOrange ? .black.opacity(0.15) : .white.opacity(0.2)
        }
    }
}

/// 하단 알약 버튼 (−, +, +30, 건너뛰기).
struct WatchPill: View {
    let label: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: prominent ? 15 : 20, weight: prominent ? .bold : .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: WatchMetrics.pillHeight)
                .background(prominent ? Color.brand : Color.card, in: Capsule())
                .foregroundStyle(prominent ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

/// 제목 아래 줄: 왼쪽에 세트 점(또는 진행 바), 오른쪽에 세트 캡션.
struct WatchCaptionRow<Leading: View>: View {
    let caption: String
    var onOrange = false
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(alignment: .center) {
            leading()
            Spacer(minLength: 8)
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(onOrange ? .black.opacity(0.6) : .white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
        }
    }
}
