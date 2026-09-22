#if DEBUG
import SwiftUI
import WidgetKit

/// 위젯·Live Activity 를 앱 안에서 실제 크기로 그려 보는 DEBUG 화면 (`-debug.gallery home|lock|activity`).
/// 시뮬레이터 홈 화면에 위젯을 올리는 CLI 방법이 없어서 만들었다. `containerBackground`는 앱 안에서 무시되므로
/// 배경은 여기서 직접 그린다. 스크린샷: `xcrun simctl launch booted kr.co.lee.NextSet -debug.gallery home`
struct WidgetGalleryView: View {
    let page: String

    static var requestedPage: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-debug.gallery"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    // iPhone 17 (402pt) 기준 위젯 크기
    private let small = CGSize(width: 158, height: 158)
    private let medium = CGSize(width: 338, height: 158)
    private let circular = CGSize(width: 72, height: 72)
    private let rectangular = CGSize(width: 172, height: 72)
    private let inline = CGSize(width: 234, height: 26)
    private let activity = CGSize(width: 374, height: 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "Widget gallery · \(page)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                switch page {
                case "lock": lockPage
                case "activity": activityPage
                default: homePage
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.16))
        .preferredColorScheme(.dark)
    }

    // MARK: 상태 샘플

    private static func snapshot(_ display: String) -> TimerSnapshot {
        var settings = TimerSettings()
        settings.restSeconds = 90
        settings.recentSeconds = 90
        var session = TimerSession()
        switch display {
        case "running":
            session.phase = .running
            session.completedSets = 2
            session.restDuration = 90
            session.endDate = Date.now.addingTimeInterval(47)
        case "paused":
            session.phase = .paused
            session.completedSets = 2
            session.restDuration = 90
            session.pausedRemaining = 47
        case "ended":
            session.phase = .done
            session.completedSets = 3
            session.restDuration = 90
            session.doneAt = .now
        case "idleSets":
            session.completedSets = 2
        case "finished":
            settings.goalSets = 4
            session.phase = .finished
            session.completedSets = 4
        default: break
        }
        return TimerSnapshot(settings: settings, session: session)
    }

    private func entry(_ display: String) -> RestEntry {
        RestEntry(date: .now, snapshot: Self.snapshot(display))
    }

    // MARK: 페이지

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ForEach(["idle", "running"], id: \.self) { state in
                    homeWidget(state, family: .systemSmall, size: small)
                }
            }
            HStack(spacing: 14) {
                homeWidget("ended", family: .systemSmall, size: small)
                homeWidget("paused", family: .systemSmall, size: small)
            }
            ForEach(["idle", "running", "ended"], id: \.self) { state in
                homeWidget(state, family: .systemMedium, size: medium)
            }
        }
    }

    private func homeWidget(_ state: String, family: WidgetFamily, size: CGSize) -> some View {
        let e = entry(state)
        return HomeWidgetView(entry: e, family: family)
            .frame(width: size.width, height: size.height)
            .background(HomeWidgetView.backgroundColor(for: e.state), in: RoundedRectangle(cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var lockPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ForEach(["idle", "running", "ended", "finished"], id: \.self) { state in
                    LockScreenWidgetView(entry: entry(state), family: .accessoryCircular)
                        .frame(width: circular.width, height: circular.height)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
            }
            ForEach(["idle", "running", "paused", "ended"], id: \.self) { state in
                LockScreenWidgetView(entry: entry(state), family: .accessoryRectangular)
                    .frame(width: rectangular.width, height: rectangular.height, alignment: .leading)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(["idle", "running"], id: \.self) { state in
                LockScreenWidgetView(entry: entry(state), family: .accessoryInline)
                    .frame(width: inline.width, height: inline.height, alignment: .leading)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private var activityPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(["running", "paused", "ended", "idleSets", "finished"], id: \.self) { state in
                let snapshot = Self.snapshot(state)
                let card = LiveActivityCard(state: .init(settings: snapshot.settings, session: snapshot.session))
                card
                    .frame(width: activity.width)
                    .background(card.backgroundColor, in: RoundedRectangle(cornerRadius: 24))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
    }
}
#endif
