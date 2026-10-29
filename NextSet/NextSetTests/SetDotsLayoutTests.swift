import XCTest
import SwiftUI
@testable import NextSet

@MainActor
final class SetDotsLayoutTests: XCTestCase {
    func testHundredDotsScrollToCurrentAndAllowReviewingEarlierSets() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        let host = UIHostingController(rootView: SetDots(dots: SetProgress(total: 100, completed: 99, finished: false)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        host.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(findScroll(in: host.view))
        XCTAssertLessThanOrEqual(scroll.bounds.width, 320)
        XCTAssertGreaterThan(scroll.contentSize.width, 1000)
        XCTAssertGreaterThan(scroll.contentOffset.x, 900, "Current set 100 must be visible initially")
        scroll.setContentOffset(.zero, animated: false)
        XCTAssertEqual(scroll.contentOffset.x, 0, accuracy: 1, "Earlier sets remain scrollable")
        host.rootView = SetDots(dots: SetProgress(total: 101, completed: 100, finished: false))
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertGreaterThan(scroll.contentOffset.x, 900, "Advancing a set follows the new current dot")
    }

    func testSevenSetsKeepSevenDotsWithoutScrolling() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        let host = UIHostingController(rootView: SetDots(dots: SetProgress(total: 7, completed: 3, finished: false)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        let scroll = try XCTUnwrap(findScroll(in: host.view))
        XCTAssertEqual(scroll.contentSize.width, 92, accuracy: 1)
        XCTAssertEqual(scroll.contentOffset.x, 0, accuracy: 1)
    }

    private func findScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScroll(in: $0) }.first
    }
}
