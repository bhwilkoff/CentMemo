import XCTest

/// D14: Ben's approved starter themes, in Settings.
final class ThemesStarterUITests: DeviceTestCase {
    /// Unexamined is for purchases; it never asks about themes (Ben, 2026-11-24).
    func testUnexaminedOffersNone() {
        let app = launch(["APP_START_TAB": "unexamined"])
        XCTAssertTrue(app.staticTexts["King Soopers"].firstMatch.waitForExistence(timeout: 25))
        XCTAssertFalse(text(app, matching: "Which of these sound like you").exists)
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
