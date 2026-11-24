import XCTest

/// N4 (DESIGN S): a written memo's share is designed by the person, and no amount
/// is ever offered.
final class ShareUITests: DeviceTestCase {
    func testDesignAShare() {
        let app = launch(["APP_START_ITEM": Fixture.withMemo])
        XCTAssertTrue(text(app, matching: Fixture.withMemoTitle).waitForExistence(timeout: 25))
        let more = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'More' OR identifier == 'more'")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the ⋯ menu")
        more.tap()
        let share = app.buttons["Share"].firstMatch  // overflow-menu items keep their label, not their identifier
        XCTAssertTrue(share.waitForExistence(timeout: 5), "Share in the ⋯ menu")
        share.tap()
        XCTAssertTrue(app.navigationBars["Share this memo"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, matching: "card: First cold Sunday").waitForExistence(timeout: 5), "the card holds the memo")
        shot(app, "share-page")
        let first = app.buttons["share-word-13"], last = app.buttons["share-word-16"]
        XCTAssertTrue(reach(app, first, swipes: 4), "the memo's words")
        first.tap(); last.tap()
        XCTAssertTrue(app.buttons["share-word-15"].isSelected, "first word, then last: what is between is underlined")
        XCTAssertFalse(app.buttons["share-word-12"].isSelected)
        shot(app, "share-underlined")
        let setting = app.buttons["Setting"].firstMatch
        XCTAssertTrue(reach(app, setting, swipes: 4))
        setting.tap()
        XCTAssertTrue(reach(app, app.buttons["Tall"].firstMatch, swipes: 4))
        app.buttons["Tall"].firstMatch.tap()
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(text(app, matching: "Setting card: First cold Sunday").waitForExistence(timeout: 5), "the look changes the card")
        XCTAssertFalse(text(app, matching: "Show the amount|[$]").exists, "an amount is never offered")
        shot(app, "share-setting-tall")
        XCTAssertTrue(app.buttons["share-send"].exists)
    }

    /// D12: a whole theme as one card, places off; any memo can be left out.
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

