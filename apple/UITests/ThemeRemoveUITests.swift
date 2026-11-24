import XCTest

/// Removing a theme takes it off every memo, so it asks first. Keep it keeps it:
/// this test never removes one.
final class ThemeRemoveUITests: DeviceTestCase {
    func testRemovingAsksFirst() {
        let app = launch(["APP_START_TAB": "settings"])
        let field = app.textFields.matching(NSPredicate(format: "value == 'Being outside'")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 25))
        field.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the swipe's button")
        delete.tap()
        let keep = app.alerts.buttons["Keep it"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "it asks first")
        shot(app, "remove-theme")
        keep.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5), "and Keep it keeps it")
    }
}
