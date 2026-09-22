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
        app.buttons["운동 끝내기"].firstMatch.tap()
        let confirm = app.buttons["기록 저장 후 종료"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
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
        app.buttons["운동 끝내기"].firstMatch.tap()
        let confirm = app.buttons["기록 저장 후 종료"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
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
        app.buttons["운동 끝내기"].firstMatch.tap()
        app.buttons["기록 저장 후 종료"].tap()
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
            app.buttons["운동 끝내기"].firstMatch.tap()
            XCTAssertTrue(app.buttons["기록 저장 후 종료"].waitForExistence(timeout: 5))
            app.buttons["기록 저장 후 종료"].tap()
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
        app.buttons["운동 끝내기"].tap()
        app.buttons["기록 저장 후 종료"].tap()
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
        app.buttons["운동 끝내기"].tap()
        app.buttons["계속하기"].tap()
        XCTAssertTrue(app.buttons["timer.number"].exists)
        app.buttons["timer.number"].tap()
        app.buttons["운동 끝내기"].tap()
        XCTAssertTrue(app.buttons["기록 저장 후 종료"].waitForExistence(timeout: 5))
        capture(app, "history-confirm-exit")
        app.buttons["기록 저장 후 종료"].tap()
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
        XCTAssertTrue(app.buttons["최근 운동"].waitForExistence(timeout: 20))
        let end = app.buttons["운동 끝내기"]
        XCTAssertTrue(end.exists)
        end.tap()
        app.buttons["기록 저장 후 종료"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 5))
        let history = app.buttons["최근 운동"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.staticTexts["1세트 완료"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "history-between-sets"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor
    func testReleasePrivacyAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-timer.reset", "-sync.off"]
        app.launch()
        app.buttons["설정"].tap()
        XCTAssertFalse(app.switches["세트 끝 자동 감지"].exists)
        let privacy = app.buttons["개인정보 처리방침"]
        for _ in 0..<4 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Rest alerts"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Paused"].exists)
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
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        let remaining = number.label
        for orientation in [UIDeviceOrientation.portrait, .landscapeRight, .portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            sleep(1)
            XCTAssertTrue(number.waitForExistence(timeout: 5))
            XCTAssertEqual(number.label, remaining, "Resizing must preserve paused time")
            XCTAssertTrue(app.staticTexts["Paused"].exists)
        }
        reveal(app.buttons["Skip"], in: app)
        captureDevice("adaptive-paused-landscape")
        app.buttons["Skip"].tap()
        let rest = app.buttons["Start rest now"]
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        reveal(rest, in: app)
        captureDevice("adaptive-rest-ended-landscape")
        reveal(app.buttons["End workout"], in: app)
        app.buttons["End workout"].tap()
        app.buttons["Save and end"].tap()
        let finish = app.buttons["Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        reveal(finish, in: app)
        captureDevice("adaptive-summary-landscape")
        finish.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
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
