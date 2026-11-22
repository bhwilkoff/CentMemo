import XCTest

/// The open Duo (regular width): the list stays on the left and a tapped
/// purchase opens on the right, never pushing the list away. On a compact
/// phone this test skips itself: the push is MemoUITests' job.
final class DuoTwoPaneUITests: DeviceTestCase {
    func testTapOpensOnTheRight() throws {
        let app = launch(["APP_START_TAB": "ledger"])
        XCTAssertTrue(text(app, matching: "Spent|Paid or credited").waitForExistence(timeout: 30))
        // Regular width shows the first purchase already open on the right.
        let detail = app.textViews.firstMatch
        guard detail.waitForExistence(timeout: 10) else {
            throw XCTSkip("compact width: no second pane (the iPhone 12 pushes instead)")
        }
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Nov'"))
        XCTAssertGreaterThan(rows.count, 2, "the list's rows are buttons at regular width")
        let second = rows.element(boundBy: 1)
        let merchant = String(second.label.split(separator: ",").first ?? "")
        second.tap()
        XCTAssertTrue(text(app, matching: "Spent|Paid or credited").waitForExistence(timeout: 5), "the list is still on screen (no push)")
        let both = app.staticTexts.matching(NSPredicate(format: "label == %@", merchant))
        let shown = NSPredicate { _, _ in both.count >= 2 }
        expectation(for: shown, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
