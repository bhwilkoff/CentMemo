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
        XCTAssertFalse(text(app, matching: "Show the amount").exists, "an amount is never offered")
        XCTAssertFalse(text(app, matching: "Setting card: ").label.contains("$"), "and none is on the card")
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
        XCTAssertTrue(text(app, matching: "Great meals: .*Anniversary").waitForExistence(timeout: 5), "the card holds the theme's memos")
        XCTAssertFalse(text(app, matching: "Show the amount").exists, "an amount is never offered")
        shot(app, "share-theme")
        app.buttons["Lines"].firstMatch.tap()
        shot(app, "share-theme-lines")
        XCTAssertTrue(app.buttons["share-theme-send"].exists)
        app.buttons["Done"].tap()
    }

    /// DESIGN S7: a link is made, listed in Settings, and turned off; no amount anywhere.
    func testMakeALinkThenTurnItOff() {
        let app = launch(["APP_START_ITEM": Fixture.withMemo, "APP_START_SHARE": "link"])
        XCTAssertTrue(app.navigationBars["Link to this memo"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS 'penguins'")).firstMatch.waitForExistence(timeout: 15), "the reader's page, live")
        XCTAssertFalse(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).firstMatch.exists, "no amount on it")
        let first = app.buttons["share-word-13"], last = app.buttons["share-word-16"]
        XCTAssertTrue(reach(app, first, swipes: 4))
        first.tap(); last.tap()
        XCTAssertTrue(app.buttons["share-word-15"].isSelected)
        let circle = app.buttons["Circle"].firstMatch
        XCTAssertTrue(reach(app, circle, swipes: 4))
        circle.tap()
        shot(app, "link-maker")
        let name = app.textFields["link-from"]
        XCTAssertTrue(reach(app, name, swipes: 6), "Shared by")
        name.tap(); name.typeText("Sam")
        XCTAssertTrue(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Shared by Sam'")).firstMatch.waitForExistence(timeout: 8), "the page says who, as they type")
        sleep(1)
        XCTAssertTrue(name.isHittable, "the field stays in sight while they type")
        shot(app, "link-typing")
        app.buttons["link-make"].tap()
        XCTAssertTrue(app.buttons["link-send"].waitForExistence(timeout: 20), "then the link can be sent")
        XCTAssertTrue(text(app, matching: "centmemo.com/s/#").waitForExistence(timeout: 5), "and its address is shown")
        shot(app, "link-made")

        let again = launch(["APP_START_TAB": "settings", "APP_START_PANE": "links"])
        let off = again.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'link-off-'")).firstMatch
        _ = again.navigationBars["Settings"].waitForExistence(timeout: 25)
        XCTAssertTrue(reach(again, off, swipes: 10), "Settings lists it")
        shot(again, "link-settings")
        let before = again.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'link-off-'")).count
        off.tap()
        let fewer = NSPredicate { _, _ in again.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'link-off-'")).count < before }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: nil)], timeout: 12), .completed, "and turns it off")
        shot(again, "link-off")
    }

    /// A whole theme's page: its parts are the writer's, and an empty page can't be made.
    func testThemeLinkParts() {
        let app = launch()
        openTab(app, "Story")
        let theme = app.buttons["theme-Great meals"]
        XCTAssertTrue(theme.waitForExistence(timeout: 25))
        theme.tap()
        let link = app.buttons["link-theme"]
        XCTAssertTrue(link.waitForExistence(timeout: 15), "Make a link, when one theme is shown")
        link.tap()
        XCTAssertTrue(app.navigationBars["Link to this theme"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Great meals'")).firstMatch.waitForExistence(timeout: 15))
        shot(app, "link-theme")
        let cover = app.switches["Cover"]
        for _ in 0..<12 where !(cover.exists && cover.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        for name in ["Cover", "Lines", "Each memory"] { app.switches[name].switches.firstMatch.exists ? app.switches[name].switches.firstMatch.tap() : app.switches[name].tap() }
        XCTAssertFalse(app.buttons["link-make"].isEnabled, "a page with no parts can't be made")
        shot(app, "link-theme-empty")
        app.buttons["Done"].firstMatch.tap()
    }
}
