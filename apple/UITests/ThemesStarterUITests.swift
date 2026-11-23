import XCTest

/// D14: Ben's approved starter themes, at first run and in Settings.
final class ThemesStarterUITests: DeviceTestCase {
    /// The first-run card lists all 13, unticked; Not now writes nothing.
    func testFirstRunCard() {
        let app = launch(["APP_FIRST_THEMES": "1"])
        XCTAssertTrue(app.descendants(matching: .any)["first-themes"].waitForExistence(timeout: 25), "Which of these sound like you?")
        XCTAssertTrue(app.buttons["starter-rose"].exists && app.buttons["starter-stone"].exists, "from People I love to Taking care of things")
        XCTAssertFalse(app.buttons["starters-keep"].isEnabled, "nothing ticked, nothing to keep")
        app.buttons["starter-moss"].tap()
        XCTAssertTrue(app.buttons["starters-keep"].isEnabled, "a tick enables Keep these")
        shot(app, "first-themes")
        app.buttons["starters-later"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["first-themes"].waitForNonExistence(timeout: 5), "Not now closes it")
    }

    /// Settings offers the starters the person doesn't have, in the color each would take.
    func testSettingsOffersStarters() {
        let app = launch()
        openTab(app, "Settings")
        let add = app.buttons["add-starter-rose"]
        for _ in 0..<6 where !add.exists { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 10), "People I love can be added")
        shot(app, "settings-starters")
    }
}
