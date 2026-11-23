import XCTest

/// D9: the Narrative's filter menu shows only some kinds of events.
final class FilterUITests: DeviceTestCase {
    func testWrittenOnly() {
        let app = launch(["APP_START_TAB": "ledger"])
        XCTAssertTrue(text(app, matching: "Spent|Paid or credited").waitForExistence(timeout: 30))
        let waiting = text(app, matching: "King Soopers")
        XCTAssertTrue(waiting.waitForExistence(timeout: 10), "an unwritten event shows by default")
        let menu = app.buttons["narrative-filter"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "the filter menu")
        menu.tap()
        let written = app.buttons["Written"]
        XCTAssertTrue(written.waitForExistence(timeout: 5), "Show: Written")
        written.tap()
        XCTAssertTrue(text(app, matching: "penguins").waitForExistence(timeout: 5), "a written memo stays")
        XCTAssertFalse(text(app, matching: "King Soopers").exists, "the unwritten event is filtered out")
        shot(app, "filter-written")
    }
}
