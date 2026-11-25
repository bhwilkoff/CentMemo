import XCTest

/// Two columns (iPad, the open Duo): scrolling the right one leaves the left one's title
/// where it is (Ben, 2026-11-25).
final class TwoColumnUITests: DeviceTestCase {
    private func check(_ app: XCUIApplication, _ title: String, scroll: XCUIElement, says: String, scrolls: Bool = true) {
        let word = app.staticTexts.matching(NSPredicate(format: "label == %@", title))
        XCTAssertTrue(word.firstMatch.waitForExistence(timeout: 30), "\(title) is on screen")
        XCTAssertTrue(scroll.waitForExistence(timeout: 20), "\(says) is there to scroll")
        sleep(2)
        // The largest is the column's title; a tab can carry the same word.
        func top() -> CGRect { word.allElementsBoundByIndex.map(\.frame).max { $0.height < $1.height } ?? .zero }
        let before = top()
        let scrolled = scroll.frame.minY
        shot(app, "\(title)-before")
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.7))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(1)
        shot(app, "\(title)-after")
        if scrolls { XCTAssertNotEqual(scrolled, scroll.frame.minY, "\(title): the right column did scroll") }
        XCTAssertEqual(before, top(), "\(title): the left title stays put while the right column scrolls")
        XCTAssertGreaterThan(before.height, 30, "\(title) is a column title, not a bar's")
    }

    func testTitlesStayPut() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        var app = launch(["APP_START_TAB": "unexamined"])
        try XCTSkipUnless(app.windows.firstMatch.horizontalSizeClass == .regular, "one column here")
        check(app, "Unexamined", scroll: app.textViews["memo-editor"], says: "the purchase")
        app.terminate()
        app = launch(["APP_START_TAB": "ledger"])
        check(app, "Narrative", scroll: app.textViews["memo-editor"], says: "the purchase")
        app.terminate()
        app = launch(["APP_START_TAB": "story"])
        check(app, "Story", scroll: text(app, matching: "penguins"), says: "the Story", scrolls: false)  // the sample fits
        app.terminate()
        app = launch(["APP_START_TAB": "settings", "APP_START_PANE": "themes"])
        check(app, "Settings", scroll: app.buttons["add-starter-plum"].firstMatch, says: "the themes")
    }
}
