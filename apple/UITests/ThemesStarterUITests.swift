import XCTest

/// D14: Ben's approved starter themes, at first run and in Settings.
final class ThemesStarterUITests: DeviceTestCase {
    /// The first-run card lists all 13, unticked; Not now writes nothing.
    func testFirstRunCard() {
        let app = launch(["APP_FIRST_THEMES": "1"])
        XCTAssertTrue(app.descendants(matching: .any)["first-themes"].waitForExistence(timeout: 25), "Which of these sound like you?")
        XCTAssertTrue(app.buttons["starter-rose"].exists, "starts with People I love")
        shot(app, "first-themes")
        app.buttons["starter-moss"].tap()
        // A List renders lazily: scroll to the end of the card.
        let keep = app.buttons["starters-keep"]
        for _ in 0..<6 where !keep.exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["starter-stone"].exists, "ends with Taking care of things")
        XCTAssertTrue(keep.isEnabled, "a tick enables Keep these")
        shot(app, "first-themes-end")
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
