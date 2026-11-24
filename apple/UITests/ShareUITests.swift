import XCTest

/// D12: a written memo shares as a card; the place and the amount stay off
/// until the person turns them on.
final class ShareUITests: DeviceTestCase {
    func testShareCardIsPrivateByDefault() {
        let app = launch(["APP_START_ITEM": Fixture.withMemo])
        XCTAssertTrue(text(app, matching: Fixture.withMemoTitle).waitForExistence(timeout: 25))
        let more = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'More' OR identifier == 'more'")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the ⋯ menu")
        more.tap()
        let share = app.buttons["Share"].firstMatch  // overflow-menu items keep their label, not their identifier
        XCTAssertTrue(share.waitForExistence(timeout: 5), "Share in the ⋯ menu")
        share.tap()
        XCTAssertTrue(app.navigationBars["Share this memo"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, matching: "penguins").exists, "the memo is on the card")
        XCTAssertTrue(text(app, matching: "Time with my kids|Being outside").exists, "its theme is on the card")
        // The card's line under the memo: the date alone by default (the event page
        // behind the sheet also says "Denver Zoo", so check this line, not the screen).
        let line = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Nov 16, 2026'")).firstMatch
        XCTAssertTrue(line.exists, "the card's date line")
        XCTAssertEqual(line.label, "Nov 16, 2026", "the place is off by default")
        XCTAssertFalse(text(app, matching: "Show the amount").exists, "an amount is never offered")
        shot(app, "share-default")
        // A tap at a Toggle row's center lands on its label and does nothing: tap the switch.
        app.switches["share-place"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Nov 16, 2026 · Denver Zoo"].waitForExistence(timeout: 5), "Show where adds the place")
        shot(app, "share-with-place")
    }

    /// D12: a whole theme as one card, places and amounts off; any memo can be left out.
    func testShareTheme() {
        let app = launch()
        openTab(app, "Story")
        let theme = app.buttons["theme-Great meals"]
        XCTAssertTrue(theme.waitForExistence(timeout: 25), "the Story's theme shelf")
        theme.tap()
        let share = app.buttons["share-theme"]
        XCTAssertTrue(share.waitForExistence(timeout: 15), "Share this theme, when one theme is shown")
        share.tap()
        XCTAssertTrue(app.navigationBars["Share this theme"].waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, matching: "Anniversary").exists, "the card holds the theme's memos")
        XCTAssertFalse(text(app, matching: "Show the amount").exists, "an amount is never offered")
        shot(app, "share-theme")
        app.buttons["Done"].tap()
    }
}

