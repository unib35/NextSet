#if os(watchOS)
import WatchKit
#else
import AVFoundation
import UIKit
#endif

extension AlertSound {
    /// 휴식 끝 벨. 앱 번들 `Sounds/`의 파일 — 앱 안 재생과 알림 배너가 같은 파일을 쓴다 (tools/make_sounds.py 참고).
    var fileName: String? {
        switch self {
        case .off: nil
        case .on: "rest-end.caf"
        }
    }

    /// 마지막 3초 매초 울리는 작은 beep (합성).
    static let countdownBeepFileName = "countdown-beep.caf"
}

#if os(watchOS)
/// 워치: 손목 햅틱만 (4f "손목 햅틱"). 소리는 내지 않는다.
final class RestFeedback {
    func countdownTick(_ level: HapticLevel, sound: AlertSound) {
        switch level {
        case .off: break
        case .light: WKInterfaceDevice.current().play(.click)
        case .strong: WKInterfaceDevice.current().play(.directionUp)
        }
    }

    func restEnded(haptic: HapticLevel, sound: AlertSound) {
        switch haptic {
        case .off: break
        case .light: WKInterfaceDevice.current().play(.notification)
        case .strong: WKInterfaceDevice.current().play(.success)
        }
    }

    func preview(_ sound: AlertSound) {}

    func previewHaptic(_ level: HapticLevel) { restEnded(haptic: level, sound: .off) }

    /// 일시정지(stop)·재개(start) 확인 햅틱.
    func pauseToggled(isPaused: Bool, level: HapticLevel) {
        guard level != .off else { return }
        WKInterfaceDevice.current().play(isPaused ? .stop : .start)
    }
}
#else
/// 햅틱과 소리를 한곳에서 낸다.
///
/// 소리는 무음 스위치를 무시하고(`.playback`), 음악과 섞이되 재생 중에는 음악을 잠시 줄인다(`.duckOthers`).
/// 재생이 끝나면 세션을 비활성화해서 음악 볼륨을 되돌린다. 이유는 `docs/DECISIONS.md` 참고.
final class RestFeedback: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var beepPlayer: AVAudioPlayer?

    /// 3 · 2 · 1 — 햅틱 + (소리 켬이면) 작은 beep. beep 은 별도 플레이어라 벨과 겹쳐도 서로 끊지 않는다.
    func countdownTick(_ level: HapticLevel, sound: AlertSound) {
        switch level {
        case .off: break
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .strong: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        guard sound == .on else { return }
        if beepPlayer == nil,
           let url = Bundle.main.url(forResource: AlertSound.countdownBeepFileName, withExtension: nil) {
            beepPlayer = try? AVAudioPlayer(contentsOf: url)
            beepPlayer?.prepareToPlay()
        }
        activateSession()
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }

    func restEnded(haptic: HapticLevel, sound: AlertSound) {
        switch haptic {
        case .off: break
        case .light: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        play(sound)
    }

    /// 설정에서 소리를 바꿨을 때 미리 들려준다.
    func preview(_ sound: AlertSound) {
        play(sound)
    }

    /// 일시정지·재개 확인 햅틱 — 정지는 단단하게(rigid), 재개는 가볍게(soft). 세기 설정이 "끔"이면 없음.
    func pauseToggled(isPaused: Bool, level: HapticLevel) {
        guard level != .off else { return }
        UIImpactFeedbackGenerator(style: isPaused ? .rigid : .soft).impactOccurred()
    }

    /// 설정에서 햅틱 세기를 바꿨을 때 바로 느끼게 — 휴식 끝과 같은 햅틱.
    func previewHaptic(_ level: HapticLevel) {
        switch level {
        case .off: break
        case .light: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - 재생

    private func play(_ sound: AlertSound) {
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        player?.stop()
        do {
            activateSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
        } catch {
            deactivateSession()
        }
    }

    @discardableResult
    private func activateSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.deactivateSession()
        }
    }

    private func deactivateSession() {
        // notifyOthersOnDeactivation: 줄여 놓은 음악 볼륨을 되돌린다.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
