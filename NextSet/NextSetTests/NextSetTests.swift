//
//  NextSetTests.swift
//  NextSetTests
//
//  Created by 이종민 on 9/16/26.
//

import AVFoundation
import Foundation
import Testing
@testable import NextSet

@MainActor
struct RestTimerTests {
    final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 0)
    }

    private func makeTimer(_ clock: Clock,
                           defaults: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!,
                           configure: (inout TimerSettings) -> Void = { _ in }) -> RestTimer {
        let liveActivity = RestActivityController()
        liveActivity.isEnabled = false
        let timer = RestTimer(defaults: defaults,
                              notifications: RestNotifications(isEnabled: false),
                              liveActivity: liveActivity,
                              clock: { clock.now })
        configure(&timer.settings)
        return timer
    }

    @Test func restEndCountsSetThenReturnsToIdle() {
        let clock = Clock()
        let timer = makeTimer(clock)
        #expect(timer.startLabel == "첫 세트 끝 → 휴식")

        timer.start()
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 60)

        clock.now += 60
        timer.tick()
        #expect(timer.session.phase == .done)
        #expect(timer.session.completedSets == 1)
        #expect(timer.nextSetNumber == 2)

        clock.now += 1
        timer.tick()
        #expect(timer.session.phase == .done)

        // 세트 모드의 휴식 끝 화면은 탭할 때까지 유지된다 (자동 복귀 없음)
        clock.now += 60
        timer.tick()
        #expect(timer.session.phase == .done)

        timer.goToSetup()  // "시간 바꾸기"
        #expect(timer.session.phase == .idle)
        #expect(timer.session.completedSets == 1)
        #expect(timer.setCaption == "세트 1 완료")
        #expect(timer.startLabel == "휴식 시작")
    }

    @Test func pauseFreezesRemaining() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 20
        timer.togglePause()
        #expect(timer.session.phase == .paused)

        clock.now += 100
        timer.tick()
        #expect(timer.displaySeconds == 40)

        timer.togglePause()
        clock.now += 39.5
        timer.tick()
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 1)
    }

    @Test func plusThirtyExtendsCurrentRestOnly() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 50
        timer.addThirtySeconds()
        #expect(timer.displaySeconds == 40)
        #expect(timer.settings.restSeconds == 60)

        clock.now += 40
        timer.tick()
        #expect(timer.session.phase == .done)
        #expect(timer.session.totalRested == 90)
    }

    /// 3b: −10 / +10 / +30. 남은 시간은 1초 밑으로 안 내려가고, 다음 휴식 길이는 안 바뀐다.
    @Test func adjustRemainingClampsAtOneSecond() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 55
        timer.adjustRemaining(by: -10)
        #expect(timer.displaySeconds == 1)
        #expect(timer.session.restDuration == 56)
        timer.adjustRemaining(by: 10)
        #expect(timer.displaySeconds == 11)
        timer.togglePause()
        timer.adjustRemaining(by: -10)
        #expect(timer.displaySeconds == 1)
        #expect(timer.settings.restSeconds == 60)

        timer.restartRest()
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 60)
        #expect(timer.session.completedSets == 0)
        timer.handleURL(URL(string: "nextset://add?seconds=10")!)
        #expect(timer.displaySeconds == 70)
    }

    @Test func skipCountsPartialRest() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 15
        timer.skip()
        #expect(timer.session.phase == .done)
        #expect(timer.session.completedSets == 1)
        #expect(timer.session.skippedCount == 1)
        #expect(timer.session.totalRested == 15)
    }

    @Test func reachingGoalFinishesWorkout() {
        let clock = Clock()
        let timer = makeTimer(clock) { $0.goalSets = 2 }
        timer.start()
        clock.now += 60
        timer.tick()
        #expect(timer.session.phase == .done)
        #expect(timer.setCaption == "세트 1/2")

        clock.now += 2
        timer.tick()
        timer.start()
        clock.now += 60
        timer.tick()
        #expect(timer.session.phase == .finished)
        #expect(timer.session.completedSets == 2)
        #expect(timer.dots == [.past, .past])

        timer.startOver()
        #expect(timer.session == TimerSession())
    }

    @Test func endWorkoutShowsToastAndResets() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 60
        timer.tick()
        clock.now += 2
        timer.tick()
        #expect(timer.canEndWorkout)

        timer.start()
        clock.now += 30
        timer.endWorkout()
        // 세트가 있으면 완료 요약(3d)으로 — 목표 세트가 없어도
        #expect(timer.session.phase == .finished)
        #expect(timer.session.completedSets == 1)
        #expect(timer.session.totalRested == 90)
        #expect(timer.dots == [.past])
        #expect(timer.toast == nil)

        timer.endWorkout()  // 요약의 "끝내기"
        #expect(timer.session == TimerSession())
    }

    @Test func endWorkoutWithoutSetsResetsAndToasts() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 20
        timer.endWorkout()
        #expect(timer.session.phase == .idle)
        #expect(timer.toast == "휴식 0:20 · 기록 저장됨")
    }

    @Test func catchesUpAfterBeingAway() {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        makeTimer(clock, defaults: defaults).start()

        clock.now += 20
        let restored = makeTimer(clock, defaults: defaults)
        #expect(restored.session.phase == .running)
        #expect(restored.displaySeconds == 40)

        clock.now += 300
        restored.tick()
        #expect(restored.session.phase == .done)  // 휴식 끝 화면 유지 — 다시 켰을 때 "세트 2 시작"이 보인다
        #expect(restored.session.completedSets == 1)
    }

    @Test func singleModeDoesNotCountSets() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.selectMode(.single)
        #expect(timer.startLabel == "시작")
        timer.start()
        clock.now += 60
        timer.tick()
        #expect(timer.session.phase == .done)
        #expect(timer.session.completedSets == 0)
        #expect(timer.setCaption == "1회")
        // 카운트다운 모드만 잠시 후 대기로 돌아간다
        clock.now += RestTimer.doneScreenDuration
        timer.tick()
        #expect(timer.session.phase == .idle)
    }

    @Test func finalCountdownSteps() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.start()
        clock.now += 56.5
        timer.tick()
        #expect(!timer.isFinalCountdown)

        clock.now += 1
        timer.tick()
        #expect(timer.isFinalCountdown)
        #expect(timer.countdownStep == 0)

        clock.now += 1
        timer.tick()
        #expect(timer.countdownStep == 1)

        timer.settings.countdownHaptics = false
        #expect(!timer.isFinalCountdown)
    }

    @Test func settingsAdjustments() {
        let timer = makeTimer(Clock())
        timer.adjustGoal(by: 1)
        #expect(timer.goalLabel == "2세트")
        timer.adjustGoal(by: -1)
        timer.adjustGoal(by: -1)
        #expect(timer.goalLabel == "무제한")

        timer.setRestSeconds(3)
        #expect(timer.settings.restSeconds == 5)
        timer.adjustRestSeconds(by: 1000)
        #expect(timer.settings.restSeconds == 600)
    }

    /// T-01: 앱 안 재생과 알림 배너가 같은 파일을 쓴다. 번들에 없으면 둘 다 조용히 실패하므로 여기서 잡는다.
    @Test func alertSoundFilesAreBundled() {
        var fileNames = AlertSound.allCases.compactMap(\.fileName)
        fileNames.append(AlertSound.countdownBeepFileName)
        #expect(fileNames == ["rest-end.caf", "countdown-beep.caf"])
        for fileName in fileNames {
            let url = Bundle.main.url(forResource: fileName, withExtension: nil)
            #expect(url != nil, "\(fileName) 이 번들에 없다")
            guard let url else { continue }
            // 알림 소리는 30초 미만이어야 한다. 디코딩이 되는지도 여기서 확인한다.
            let player = try? AVAudioPlayer(contentsOf: url)
            #expect(player != nil, "\(fileName) 을 디코딩할 수 없다")
            #expect((player?.duration ?? 0) > 0.05)
            #expect((player?.duration ?? 99) < 30)
        }
    }

    /// T-01: 실제 재생 경로를 한 번 태운다. 오디오 세션이 `.playback`으로 잡히고 재생이 끝나면 비활성화돼야 한다.
    @Test func playingSoundConfiguresAudioSession() async throws {
        let feedback = RestFeedback()
        feedback.preview(.on)
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
        #expect(session.categoryOptions.contains(.mixWithOthers))
        #expect(session.categoryOptions.contains(.duckOthers))
        try await Task.sleep(for: .seconds(1.5))  // 0.9초짜리 소리가 끝나고 delegate 가 돌 때까지
    }

    /// T-21: 예전 `.standard` 값은 공유 저장소가 비어 있을 때 한 번만 옮긴다.
    @Test func migratesStandardDefaultsIntoSharedStoreOnce() {
        let old = UserDefaults(suiteName: UUID().uuidString)!
        let shared = UserDefaults(suiteName: UUID().uuidString)!
        var settings = TimerSettings()
        settings.restSeconds = 90
        TimerStore.save(settings, forKey: TimerStore.Keys.settings, to: old)

        TimerStore.migrate(from: old, to: shared)
        #expect(TimerStore.loadSettings(from: shared).restSeconds == 90)
        #expect(old.data(forKey: TimerStore.Keys.settings) == nil)

        // 공유 저장소에 값이 있으면 다시 덮어쓰지 않는다
        settings.restSeconds = 45
        TimerStore.save(settings, forKey: TimerStore.Keys.settings, to: old)
        TimerStore.migrate(from: old, to: shared)
        #expect(TimerStore.loadSettings(from: shared).restSeconds == 90)
    }

    /// T-21/T-24: 위젯이 보는 파생 값은 앱과 같은 계산이어야 한다.
    @Test func snapshotMatchesTimerAndDetectsEndedRest() {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let timer = makeTimer(clock, defaults: defaults) { $0.goalSets = 3 }
        timer.setRestSeconds(45)
        timer.start()

        let snapshot = TimerSnapshot(from: defaults)
        #expect(snapshot.dots == timer.dots)
        #expect(snapshot.setCaption == timer.setCaption)
        #expect(snapshot.lastPresetSeconds == 45)
        #expect(snapshot.remaining(at: clock.now) == 45)
        #expect(!snapshot.hasRestEnded(at: clock.now))
        // 앱이 잠든 사이 종료 시각이 지나면 위젯은 "휴식 끝"으로 본다
        #expect(snapshot.hasRestEnded(at: clock.now + 46))
    }

    /// T-24: 위젯 URL — 대기 중이면 마지막 프리셋으로 즉시 시작, 실행 중이면 무시.
    @Test func widgetURLStartsWithLastPreset() {
        let clock = Clock()
        let timer = makeTimer(clock)
        timer.setRestSeconds(90)
        timer.start()
        clock.now += 90
        timer.tick()
        #expect(timer.session.phase == .done)
        timer.goToSetup()
        #expect(timer.session.phase == .idle)

        timer.setRestSeconds(30)  // 화면에서 프리셋만 바꾸고 시작하지 않은 상태
        timer.settings.recentSeconds = 90
        timer.handleURL(URL(string: "nextset://start")!)
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 90)

        timer.handleURL(URL(string: "nextset://start")!)  // 실행 중 재탭은 무시
        #expect(timer.displaySeconds == 90)
        timer.handleURL(URL(string: "nextset://open")!)
        #expect(timer.session.phase == .running)

        // 5b 중형 위젯 버튼들
        timer.handleURL(URL(string: "nextset://plus30")!)
        #expect(timer.displaySeconds == 120)
        timer.handleURL(URL(string: "nextset://toggle")!)
        #expect(timer.session.phase == .paused)
        timer.handleURL(URL(string: "nextset://toggle")!)
        #expect(timer.session.phase == .running)
        timer.handleURL(URL(string: "nextset://skip")!)
        #expect(timer.session.phase == .done)
        #expect(timer.session.completedSets == 2)

        clock.now += 2
        timer.tick()
        timer.handleURL(URL(string: "nextset://start?seconds=45")!)  // 프리셋 지정 시작
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 45)
        #expect(timer.settings.recentSeconds == 45)
    }

    /// T-47: 위젯·Live Activity 버튼(AppIntent)은 `perform(_:)` 하나로 들어온다.
    @Test func performHandlesIntentActions() {
        let clock = Clock()
        let timer = makeTimer(clock) { $0.goalSets = 2 }
        timer.perform(.start(seconds: 45))
        #expect(timer.session.phase == .running)
        #expect(timer.displaySeconds == 45)
        timer.perform(.start(seconds: 30))  // 실행 중엔 무시
        #expect(timer.displaySeconds == 45)
        timer.perform(.add(seconds: 30))
        timer.perform(.togglePause)
        #expect(timer.session.phase == .paused)
        #expect(timer.displaySeconds == 75)
        timer.perform(.skip)
        #expect(timer.session.completedSets == 1)
        clock.now += 2
        timer.perform(.start(seconds: nil))
        #expect(timer.displaySeconds == 45)  // 마지막 프리셋
        clock.now += 45
        timer.tick()
        #expect(timer.session.phase == .finished)
        timer.perform(.startOver)
        #expect(timer.session == TimerSession())
        timer.perform(.start(seconds: nil))
        timer.perform(.endWorkout)
        #expect(timer.session == TimerSession())

        // 제어 센터 토글: 대기 → 시작 → 일시정지 → 재개
        timer.perform(.controlToggle)
        #expect(timer.session.phase == .running)
        timer.perform(.controlToggle)
        #expect(timer.session.phase == .paused)
        timer.perform(.controlToggle)
        #expect(timer.session.phase == .running)
    }

    /// T-32: 다른 기기에서 온 상태는 그대로 받아들이고, 되돌려 보내지 않는다(`stateDidChange` 안 부름).
    @Test func adoptAppliesRemoteStateWithoutEcho() {
        let clock = Clock()
        let timer = makeTimer(clock)
        var changes = 0
        timer.stateDidChange = { changes += 1 }

        timer.start()
        #expect(changes == 2)  // settings(recentSeconds) + session
        #expect(timer.lastChangedAt == clock.now)

        var remoteSettings = TimerSettings()
        remoteSettings.restSeconds = 90
        var remoteSession = TimerSession()
        remoteSession.phase = .running
        remoteSession.restDuration = 90
        remoteSession.endDate = clock.now + 90
        remoteSession.completedSets = 3
        let sentAt = clock.now + 1
        timer.adopt(settings: remoteSettings, session: remoteSession, changedAt: sentAt)

        #expect(changes == 2)
        #expect(timer.session.completedSets == 3)
        #expect(timer.displaySeconds == 90)
        #expect(timer.lastChangedAt == sentAt)

        // 받은 뒤 이 기기에서 조작하면 다시 보낸다
        timer.togglePause()
        #expect(changes == 3)

        // 시간이 흘러 생기는 전환(휴식 끝 → 대기)은 보내지 않는다 — 상대도 같은 계산을 한다
        timer.togglePause()
        #expect(changes == 4)
        clock.now += 90
        timer.tick()
        #expect(timer.session.phase == .done)
        #expect(changes == 4)
    }

    /// 재실행해도 마지막 변경 시각이 남아야 동기화가 옛 상태를 최신으로 오해하지 않는다.
    @Test func lastChangedAtPersistsAcrossLaunches() {
        let clock = Clock()
        clock.now = Date(timeIntervalSinceReferenceDate: 500)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        makeTimer(clock, defaults: defaults).start()
        let restored = makeTimer(clock, defaults: defaults)
        #expect(restored.lastChangedAt == clock.now)
    }

    @Test func syncPayloadRoundTrips() throws {
        var settings = TimerSettings()
        settings.goalSets = 4
        var session = TimerSession()
        session.completedSets = 2
        let sentAt = Date(timeIntervalSince1970: 1_000)
        let payload = RestSync.payload(settings: settings, session: session, sentAt: sentAt)
        #expect(payload["sentAt"] as? TimeInterval == 1_000)
        let decodedSettings = try JSONDecoder().decode(TimerSettings.self, from: try #require(payload["settings"] as? Data))
        let decodedSession = try JSONDecoder().decode(TimerSession.self, from: try #require(payload["session"] as? Data))
        #expect(decodedSettings == settings)
        #expect(decodedSession == session)
    }

    /// 설정에 항목을 추가해도 예전 저장값(키 없음)이 기본값으로 채워져 읽힌다.
    @Test func settingsDecodeWithMissingKeys() throws {
        let json = #"{"restSeconds":45,"goalSets":3,"sound":"long"}"#  // "long"은 예전 값 → 켬
        let settings = try JSONDecoder().decode(TimerSettings.self, from: Data(json.utf8))
        #expect(settings.restSeconds == 45)
        #expect(settings.goalSets == 3)
        #expect(settings.sound == .on)
        #expect(settings.haptic == .strong)
        #expect(settings.widgetTap == .start)
        #expect(settings.liveActivity)
    }

    /// 6c/6d 힌트 시점: 저장된 운동 수로 판단한다.
    @Test func firstRunHintsFollowEndedWorkoutCount() {
        let clock = Clock()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let timer = makeTimer(clock, defaults: defaults)
        let hints = FirstRunHints(defaults: defaults)
        #expect(timer.endedWorkoutCount == 0)
        #expect(hints.showsLockScreenHint(endedWorkouts: timer.endedWorkoutCount))
        #expect(!hints.showsWatchHint(endedWorkouts: 0, isWatchPaired: true))

        timer.start(); clock.now += 60; timer.tick(); timer.endWorkout(); timer.endWorkout()  // 1세트 → 요약 → 끝내기
        #expect(timer.endedWorkoutCount == 1)
        #expect(hints.showsWatchHint(endedWorkouts: 1, isWatchPaired: true))
        #expect(!hints.showsWatchHint(endedWorkouts: 1, isWatchPaired: false))
        #expect(!hints.showsWidgetGuideHint(endedWorkouts: 1))

        timer.start(); clock.now += 60; timer.tick(); timer.endWorkout(); timer.endWorkout()
        #expect(timer.endedWorkoutCount == 2)
        #expect(hints.showsWidgetGuideHint(endedWorkouts: 2))
        hints.markWidgetGuideSeen()
        #expect(!FirstRunHints(defaults: defaults).showsWidgetGuideHint(endedWorkouts: 2))
        #expect(makeTimer(clock, defaults: defaults).endedWorkoutCount == 2)
    }

    @Test func formatsRestTotals() {
        #expect(RestTimer.format(90) == "1:30")
        #expect(RestTimer.format(59.2) == "1:00")
        #expect(RestTimer.format(5) == "0:05")
    }
}
