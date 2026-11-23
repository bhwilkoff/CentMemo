import XCTest

/// D12: Themes are the Story's collections. Tapping one shows only its memos;
/// "Every memo" goes back.
final class ThemesUITests: DeviceTestCase {
    func testThemeCollection() {
        let app = launch(["APP_START_TAB": "story"])
        let meals = app.buttons["theme-Great meals"]
        XCTAssertTrue(meals.waitForExistence(timeout: 30), "the Great meals collection")
        XCTAssertTrue(text(app, matching: "penguins").waitForExistence(timeout: 10), "the month's memos show first")
        meals.tap()
        XCTAssertTrue(text(app, matching: "Anniversary").waitForExistence(timeout: 10), "a Great meals memo")
        XCTAssertFalse(text(app, matching: "penguins").exists, "a memo from another theme is not in this collection")
        shot(app, "theme-great-meals")
        app.buttons["every-memo"].tap()
        XCTAssertTrue(text(app, matching: "penguins").waitForExistence(timeout: 10), "Every memo goes back")
    }
}
