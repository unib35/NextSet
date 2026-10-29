//
//  NextSetUITests.swift
//  NextSetUITests
//
//  Created by 이종민 on 9/16/26.
//

import XCTest

/// 화면을 실제로 조작하며 상태별 스크린샷을 남긴다.
/// 결과는 `xcrun xcresulttool export attachments` 로 꺼내 본다 (docs/PROJECT.md 참고).
final class NextSetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// T-24: 위젯 탭(`nextset://start`) → 앱이 열리며 마지막 프리셋으로 바로 휴식 시작.
    @MainActor
    func testWidgetURLStartsRestImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        XCTAssertTrue(app.buttons["첫 세트 끝 → 휴식"].waitForExistence(timeout: 10))

        app.open(URL(string: "nextset://start")!)
        let number = app.buttons["timer.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 10), "URL 을 열면 휴식 중 화면이어야 한다")
        capture(app, "widget-url-start")
    }

    /// T-22/T-23: Live Activity 흐름을 스크린샷으로 남긴다 — Dynamic Island 축소/확장, 앱이 잠든 뒤 "휴식 끝"(stale),
    /// 확장 뷰의 "휴식 시작" 버튼(LiveActivityIntent → 앱 프로세스), 잠금화면 카드.
    @MainActor
    func testLiveActivityFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        let preset30 = app.buttons["30초"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 10))
        preset30.tap()
        app.buttons["첫 세트 끝 → 휴식"].tap()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // 새 시뮬레이터에서는 첫 휴식 시작 때 알림 권한 팝업이 뜬다. 섬 버튼을 가리므로 먼저 허용한다.
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN {'허용', 'Allow'}")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap(); sleep(1) }
        XCUIDevice.shared.press(.home)
        sleep(3)
        capture(springboard, "la-01-island-compact")

        let island = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.045))
        island.press(forDuration: 1.0)
        sleep(2)
        capture(springboard, "la-02-island-expanded")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()

        // 앱을 죽인 채 휴식이 끝난다 → 앱이 update 를 못 한다. staleDate 재렌더는 시스템이 늦게(약 90초 뒤) 처리하므로
        // 여기서는 기다리지 않고, 버튼(인텐트)이 죽은 앱을 띄워 상태를 바로잡는지만 본다.
        app.terminate()
        sleep(32)
        capture(springboard, "la-03-island-after-end")
        island.press(forDuration: 1.0)
        sleep(2)
        capture(springboard, "la-04-island-expanded-after-end")

        // 어떤 버튼이든 LiveActivityIntent → 시스템이 죽은 앱을 백그라운드로 띄워 perform() 실행
        let candidates = ["휴식 시작", "시작", "건너뛰기"].map { springboard.buttons[$0] }
        if let button = candidates.first(where: { $0.exists }) {
            let note = XCTAttachment(string: "tapped: \(button.label)")
            note.lifetime = .keepAlways
            add(note)
            button.tap()
            sleep(4)
            capture(springboard, "la-05-island-after-intent")
        } else {
            XCTFail("확장 뷰에 버튼이 없다")
        }

        XCUIDevice.shared.perform(Selector(("pressLockButton")))
        sleep(2)
        capture(springboard, "la-06-lockscreen")
        XCUIDevice.shared.press(.home)
        sleep(1)

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2)
        capture(app, "la-07-app-after")
    }

    /// 토스트 위치(상단)와 최근 운동 화면 스타일을 스크린샷으로 남긴다.
    @MainActor
    func testToastAndHistoryScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        let start = app.buttons["첫 세트 끝 → 휴식"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        holdToEnd(app)
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        capture(app, "toast-top")

        let history = app.buttons["최근 운동"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.buttons["완료"].waitForExistence(timeout: 5))
        sleep(1)
        capture(app, "history")
        app.buttons["완료"].tap()
    }

    /// 휴식 끝 알림을 탭해 앱에 들어가는 두 경우(앱이 뒤에 살아 있을 때 / 앱이 꺼져 있을 때)에 앱이 정상 실행되는지.
    /// 배너는 바깥에서 `xcrun simctl push`로 띄운다(로컬 알림 타이밍에 안 묶이게) — 실행 절차는 docs/PROJECT.md.
    @MainActor
    func testNotificationTapOpensApp() throws {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        let allow = springboard.buttons["허용"].firstMatch
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        XCTAssertTrue(app.buttons["첫 세트 끝 → 휴식"].waitForExistence(timeout: 10))

        // 1) 앱이 뒤에 살아 있을 때
        XCUIDevice.shared.press(.home)
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "휴식 끝")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 90), "휴식 끝 알림 배너가 떠야 한다 (push 필요)")
        capture(springboard, "notif-01-banner-warm")
        banner.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "알림 탭 → 앱이 포그라운드여야 한다")
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground, "앱이 꺼지면 안 된다 (warm)")
        capture(app, "notif-02-after-tap-warm")

        // 2) 앱이 꺼져 있을 때 (콜드 런치)
        app.terminate()
        let banner2 = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "휴식 끝")).firstMatch
        XCTAssertTrue(banner2.waitForExistence(timeout: 120), "휴식 끝 알림 배너가 떠야 한다 (앱 꺼짐, push 필요)")
        capture(springboard, "notif-03-banner-cold")
        banner2.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "콜드 런치 → 앱이 포그라운드여야 한다")
        sleep(4)
        XCTAssertEqual(app.state, .runningForeground, "콜드 런치 뒤 앱이 꺼지면 안 된다")
        capture(app, "notif-04-after-tap-cold")
    }

    /// 목표 세트 없이 운동을 끝내도 완료 요약(3d)이 뜬다.
    @MainActor
    func testManualEndShowsSummary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "5"]
        app.launch()
        let doneCTA = app.buttons["바로 휴식 시작"]
        XCTAssertTrue(doneCTA.waitForExistence(timeout: 20))
        app.buttons["시간 바꾸기"].tap()  // 3c 에는 종료가 없다(2026-10 시안) → 3a 의 종료
        holdToEnd(app)
        let again = app.buttons["한 번 더"]
        XCTAssertTrue(again.waitForExistence(timeout: 10), "세트가 있으면 완료 요약이 떠야 한다")
        capture(app, "summary-manual-end")
        app.buttons["끝내기"].tap()
        XCTAssertTrue(app.buttons["첫 세트 끝 → 휴식"].waitForExistence(timeout: 10))
    }

    /// 최근 운동의 휴지통 버튼 → 확인창 → 삭제.
    @MainActor
    func testHistoryExplicitDelete() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "5"]
        app.launch()
        XCTAssertTrue(app.buttons["바로 휴식 시작"].waitForExistence(timeout: 20))
        app.buttons["시간 바꾸기"].tap()
        holdToEnd(app)
        XCTAssertTrue(app.buttons["끝내기"].waitForExistence(timeout: 10))
        app.buttons["끝내기"].tap()
        let history = app.buttons["최근 운동"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        let trash = app.buttons["기록 삭제"].firstMatch
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        capture(app, "history-trash")
        trash.tap()
        let confirm = app.buttons["삭제"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        capture(app, "history-trash-confirm")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["아직 운동 기록이 없어요"].waitForExistence(timeout: 5))
        capture(app, "history-empty")
    }

    /// 6c·6d: 첫 휴식 중 잠금화면 힌트, 두 번째 종료 후 위젯 안내 → 위젯 추가하기 화면.
    @MainActor
    func testFirstRunHints() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "5"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["화면을 꺼도 잠금화면과 Dynamic Island에서 계속 보입니다"].waitForExistence(timeout: 3))
        capture(app, "hint-01-lockscreen")

        func endWorkout() {
            XCTAssertTrue(app.buttons["바로 휴식 시작"].waitForExistence(timeout: 20))
            app.buttons["시간 바꾸기"].tap()
            holdToEnd(app)
            XCTAssertTrue(app.buttons["끝내기"].waitForExistence(timeout: 10))
            app.buttons["끝내기"].tap()
            XCTAssertTrue(app.buttons["첫 세트 끝 → 휴식"].waitForExistence(timeout: 10))
        }
        endWorkout()
        XCTAssertFalse(app.staticTexts["위젯을 추가하면 앱을 열지 않고 휴식을 시작할 수 있어요."].exists)
        app.buttons["첫 세트 끝 → 휴식"].tap()  // 기본 휴식은 -timer.start 로 5초가 되어 있다
        endWorkout()
        let widgetHint = app.staticTexts["위젯을 추가하면 앱을 열지 않고 휴식을 시작할 수 있어요."]
        XCTAssertTrue(widgetHint.waitForExistence(timeout: 5), "두 번째 종료 후 위젯 안내")
        capture(app, "hint-02-widget")
        app.buttons["보기"].tap()
        XCTAssertTrue(app.staticTexts["위젯 추가하기"].waitForExistence(timeout: 5))
        capture(app, "hint-03-guide-lock")
        app.buttons["홈 화면"].tap()
        capture(app, "hint-04-guide-home")
        app.buttons["제어 센터"].tap()
        capture(app, "hint-05-guide-cc")
        app.buttons["완료"].tap()
        XCTAssertFalse(widgetHint.waitForExistence(timeout: 2), "한 번 보면 다시 안 뜬다")
    }

    @MainActor
    func testScreenTour() throws {
        let app = XCUIApplication()
        // 저장된 상태(App Group)를 지우고 시작한다. 인자 도메인 덮어쓰기는 suite 에 안 먹어서 앱이 직접 처리한다.
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()

        let start = app.buttons["첫 세트 끝 → 휴식"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        capture(app, "01-대기")

        // 설정 시트 — 목표 2세트로
        app.buttons["설정"].tap()
        openAdvancedSettings(app)
        let goalPlus = app.buttons["목표 세트 늘리기"]
        XCTAssertTrue(goalPlus.waitForExistence(timeout: 5))
        goalPlus.tap()
        capture(app, "02-설정")
        app.buttons["완료"].tap()

        // 휴식 중 / 일시정지는 기본 60초로 찍는다.
        // 요소 조회 한 번에 1~3초가 걸려서, 짧은 휴식으로 찍으면 촬영 도중 휴식이 끝나 버린다.
        start.tap()
        let number = app.buttons["timer.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 10))
        capture(app, "03-휴식중")

        number.tap()
        capture(app, "04-일시정지")

        // 마지막 3초와 휴식 끝은 30초 프리셋으로. 남은 시간 레이블을 기다린다.
        holdToEnd(app)
        let preset30 = app.buttons["30초"]
        XCTAssertTrue(preset30.waitForExistence(timeout: 10))
        preset30.tap()
        start.tap()

        // 마지막 3초 화면은 창이 3초뿐이라 요소 조회 타이밍에 따라 놓칠 수 있다 — 잡히면 찍고, 못 잡아도 실패로 치지 않는다
        let lastThree = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[123]초.*")).firstMatch
        if lastThree.waitForExistence(timeout: 45) {
            capture(app, "05-마지막3초")
        } else {
            let note = XCTAttachment(string: "마지막 3초 화면을 스크린샷으로 잡지 못함 (타이밍)")
            note.lifetime = .keepAlways
            add(note)
        }

        // 휴식 끝 화면은 탭할 때까지 유지된다
        let doneCTA = app.buttons["바로 휴식 시작"]
        XCTAssertTrue(doneCTA.waitForExistence(timeout: 30))
        sleep(3)
        XCTAssertTrue(doneCTA.exists, "휴식 끝 화면이 자동으로 사라지면 안 된다")
        capture(app, "06-휴식끝")

        // 이어서 두 번째 휴식 → 목표 2세트 달성 → 완료 요약
        doneCTA.tap()
        let restart = app.buttons["한 번 더"]
        XCTAssertTrue(restart.waitForExistence(timeout: 90))
        capture(app, "07-완료요약")
    }

    @MainActor
    func testExitWorkoutAndReadHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "60"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        capture(app, "history-running-exit")
        app.buttons["운동 끝내기"].tap()  // 짧게 누르면 "길게 누르기" 안내만, 끝나지 않는다
        capture(app, "history-short-tap-hint")
        XCTAssertTrue(app.buttons["timer.number"].exists)
        app.buttons["timer.number"].tap()
        holdToEnd(app)
        XCTAssertTrue(app.buttons["최근 운동"].waitForExistence(timeout: 10))
        app.buttons["최근 운동"].tap()
        XCTAssertTrue(app.staticTexts["0세트 완료"].waitForExistence(timeout: 5))
        // 최근 운동 행: "휴식 합계 · 평균 …" 한 줄 (2026-09-18 커스텀 스타일)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "휴식 ")).firstMatch.exists)
        capture(app, "history-record")
        app.buttons["완료"].tap()
        app.terminate()
        app.launchArguments = ["-sync.off"]
        app.launch()
        app.buttons["최근 운동"].tap()
        XCTAssertTrue(app.staticTexts["0세트 완료"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExitBetweenSetsAndReadHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "5"]
        app.launch()
        XCTAssertTrue(app.buttons["바로 휴식 시작"].waitForExistence(timeout: 20))
        app.buttons["시간 바꾸기"].tap()
        holdToEnd(app)
        let finish = app.buttons["끝내기"]  // 세트가 있으면 요약(3d)을 거친다
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        finish.tap()
        let history = app.buttons["최근 운동"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        XCTAssertTrue(app.staticTexts["1세트 완료"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "history-between-sets"; shot.lifetime = .keepAlways; add(shot)
    }

    /// T-88: iOS 26 휴식 끝 알람(AlarmKit). 첫 휴식에 알람 권한 → 홈으로 나가면 휴식 끝에 시스템 알람 화면.
    @MainActor
    func testRestEndAlarmRingsInBackground() throws {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "15"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN {'허용', 'Allow'}")).firstMatch
        if allow.waitForExistence(timeout: 5) {
            capture(springboard, "alarm-01-permission")
            allow.tap()
        }
        XCUIDevice.shared.press(.home)
        sleep(16)
        capture(springboard, "alarm-02-ringing")
        let snooze = springboard.buttons["+30초 더 쉬기"]
        let note = XCTAttachment(string: "snooze button exists: \(snooze.exists)\n" + springboard.debugDescription)
        note.lifetime = .keepAlways
        add(note)
        XCTAssertTrue(snooze.waitForExistence(timeout: 10), "휴식 끝 알람 화면에 '+30초 더 쉬기'가 보여야 한다")
        snooze.tap()
        sleep(3)
        capture(springboard, "alarm-03-snoozing")
        app.activate()  // 앱으로 돌아오면 남은 알람을 취소한다
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2)
        capture(app, "alarm-04-app")
    }

    /// T-90(시안 A5): iOS 18 은 고급 설정 › 알림에 시간 민감 알림 상태 줄, iOS 26(알람 사용)은 숨긴다.
    @MainActor
    func testAlertSettingsFollowOSVersion() throws {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "60"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN {'허용', 'Allow'}")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        app.buttons["설정"].tap()
        openAdvancedSettings(app)
        sleep(1)
        capture(app, "alert-settings")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "시간 민감 알림")).firstMatch
        let major = Int(UIDevice.current.systemVersion.split(separator: ".").first ?? "0") ?? 0
        if major >= 26 {
            XCTAssertFalse(row.exists, "알람을 쓰면 시간 민감 알림 줄은 필요 없다")
        } else {
            XCTAssertTrue(row.waitForExistence(timeout: 5), "iOS 18 은 시간 민감 알림 상태를 보여 준다")
        }
    }

    /// T-83: 휴식 중·휴식 끝 화면에서도 설정이 열리고, 시트를 연 채 휴식이 끝나도 닫히지 않는다.
    @MainActor
    func testSettingsOpensDuringWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-timer.start", "15"]
        app.launch()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 10))
        capture(app, "settings-01-running-gear")
        app.buttons["설정"].tap()
        let restPlus = app.buttons["기본 휴식 늘리기"]
        XCTAssertTrue(restPlus.waitForExistence(timeout: 5), "휴식 중에도 설정 시트가 열려야 한다")
        XCTAssertTrue(app.staticTexts["다음 휴식부터 적용"].exists)
        restPlus.tap()
        XCTAssertTrue(app.staticTexts["20초"].exists)
        capture(app, "settings-02-sheet-during-rest")

        sleep(16)  // 시트 뒤에서 휴식이 끝난다
        XCTAssertTrue(restPlus.exists, "휴식이 끝나 화면이 바뀌어도 시트가 닫히면 안 된다")
        XCTAssertFalse(app.staticTexts["다음 휴식부터 적용"].exists)
        app.buttons["완료"].tap()
        XCTAssertTrue(app.buttons["바로 휴식 시작"].waitForExistence(timeout: 5))
        capture(app, "settings-03-done-gear")

        app.buttons["설정"].tap()
        XCTAssertTrue(restPlus.waitForExistence(timeout: 5), "휴식 끝 화면에서도 설정 시트가 열려야 한다")
        app.buttons["완료"].tap()
        app.buttons["바로 휴식 시작"].tap()
        let number = app.buttons["timer.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        XCTAssertTrue(number.label.hasPrefix("20초") || number.label.hasPrefix("19초"), "바꾼 기본 휴식이 다음 휴식에 적용돼야 한다: \(number.label)")
    }

    @MainActor
    func testReleasePrivacyAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        app.buttons["설정"].tap()
        openAdvancedSettings(app)
        XCTAssertFalse(app.switches["세트 끝 자동 감지"].exists)
        let privacy = app.buttons["개인정보 처리방침"]
        for _ in 0..<4 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        sleep(1)  // 스크롤 관성이 남아 있으면 탭이 스크롤만 멈춘다
        privacy.tap()
        XCTAssertTrue(app.staticTexts["최종 수정: 2026년 9월 22일"].waitForExistence(timeout: 5))
        capture(app, "release-privacy")
        app.buttons["뒤로"].tap()
        XCTAssertTrue(app.buttons["완료"].exists)
    }

    @MainActor
    func testEnglishLocalization() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Set done → Rest"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["60s"].exists)
        capture(app, "en-setup")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Increase Default rest"].waitForExistence(timeout: 5))
        capture(app, "en-settings-quick")
        openAdvancedSettings(app, all: "All settings", advanced: "Advanced settings")
        XCTAssertTrue(app.buttons["Increase Set goal"].exists)
        app.buttons["Increase Set goal"].tap()
        XCTAssertTrue(app.staticTexts["2 sets"].exists)
        app.buttons["Decrease Set goal"].tap()
        XCTAssertTrue(app.staticTexts["1 set"].exists)
        capture(app, "en-settings")
        let guide = app.buttons["How to add widgets"]
        for _ in 0..<4 {
            if guide.isHittable { break }
            app.swipeUp()
        }
        guide.tap()
        XCTAssertTrue(app.staticTexts["Add widgets"].waitForExistence(timeout: 5))
        capture(app, "en-guide-lock")
        app.buttons["Home Screen"].tap()
        capture(app, "en-guide-home")
        app.buttons["Control Center"].tap()
        capture(app, "en-guide-control")
        app.buttons["Back"].tap()
        let privacy = app.buttons["Privacy Policy"]
        for _ in 0..<4 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        sleep(1)  // 스크롤 관성이 남아 있으면 탭이 스크롤만 멈춘다
        privacy.tap()
        XCTAssertTrue(app.staticTexts["Last updated: September 22, 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "NextSet is a workout rest timer")).firstMatch.exists)
        capture(app, "en-privacy")
        app.buttons["Back"].tap()
        app.swipeDown()
        app.buttons["Done"].tap()
        app.buttons["Set done → Rest"].tap()
        XCTAssertTrue(app.buttons["timer.number"].waitForExistence(timeout: 5))
        capture(app, "en-running")
        app.buttons["timer.number"].tap()
        XCTAssertTrue(app.staticTexts["Paused · Tap to resume"].exists)
        capture(app, "en-paused")
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Go again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["set completed"].exists)
        capture(app, "en-summary")
        app.buttons["Finish"].tap()
        app.buttons["Recent workouts"].tap()
        XCTAssertTrue(app.staticTexts["1 set completed"].waitForExistence(timeout: 5))
        capture(app, "en-history")
        app.buttons["Delete record"].firstMatch.tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Countdown"].tap()
        XCTAssertTrue(app.buttons["Start"].exists)
        capture(app, "en-countdown")
    }

    @MainActor
    func testEnglishWidgetGallery() throws {
        let app = XCUIApplication()
        for page in ["home", "lock", "activity"] {
            app.launchArguments = ["-sync.off", "-debug.gallery", page, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            XCTAssertTrue(app.staticTexts["Widget gallery · \(page)"].waitForExistence(timeout: 10))
            capture(app, "en-widgets-\(page)")
            app.swipeUp()
            capture(app, "en-widgets-\(page)-bottom")
            app.terminate()
        }
    }

    @MainActor
    func testAdaptiveTimerRotation() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launchArguments = ["-timer.reset", "-sync.off", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))  // 새 클론 시뮬레이터 첫 실행이 느리다
        captureDevice("adaptive-setup-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1) // UIKit rotation must settle before tapping coordinates.
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "Window must actually rotate to landscape")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let start = app.buttons["Set done → Rest"]
        reveal(start, in: app)
        captureDevice("adaptive-setup-landscape")
        start.tap()
        let number = app.buttons["timer.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        number.tap()
        XCTAssertTrue(app.staticTexts["Paused · Tap to resume"].exists)
        let remaining = number.label
        for orientation in [UIDeviceOrientation.portrait, .landscapeRight, .portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            sleep(1)
            XCTAssertTrue(number.waitForExistence(timeout: 5))
            XCTAssertEqual(number.label, remaining, "Resizing must preserve paused time")
            XCTAssertTrue(app.staticTexts["Paused · Tap to resume"].exists)
        }
        reveal(app.buttons["Skip"], in: app)
        captureDevice("adaptive-paused-landscape")
        app.buttons["Skip"].tap()
        let rest = app.buttons["Start rest now"]
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        reveal(rest, in: app)
        captureDevice("adaptive-rest-ended-landscape")
        app.buttons["Change time"].tap()
        reveal(app.buttons["End workout"], in: app)
        holdToEnd(app, label: "End workout")
        let finish = app.buttons["Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        reveal(finish, in: app)
        captureDevice("adaptive-summary-landscape")
        finish.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    /// 좌상단 "종료"를 길게 눌러 끝낸다(0.7초, 확인창 없음).
    @MainActor
    private func holdToEnd(_ app: XCUIApplication, label: String = "운동 끝내기") {
        let end = app.buttons[label].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.press(forDuration: 1.2)
    }

    /// 설정 시트 → "모든 설정" → "고급 설정" 펼치기.
    @MainActor
    private func openAdvancedSettings(_ app: XCUIApplication, all: String = "모든 설정", advanced: String = "고급 설정") {
        let allSettings = app.buttons[all]
        XCTAssertTrue(allSettings.waitForExistence(timeout: 5))
        allSettings.tap()
        let disclosure = app.buttons[advanced]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        disclosure.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.isHittable && app.windows.firstMatch.frame.contains(element.frame) { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(element.frame), "Control must fit inside the window")
    }

    @MainActor
    private func captureDevice(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
