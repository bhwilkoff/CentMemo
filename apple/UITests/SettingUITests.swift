import XCTest

/// D8: the event page's Setting opens every visit there; Back returns.
final class SettingUITests: DeviceTestCase {
    func testEveryVisitOpensTheSetting() {
        let app = launch(["APP_START_ITEM": Fixture.withMemo])
        let link = app.buttons["every-visit"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 25), "the Setting heads the event page")
        link.tap()
        let summary = app.staticTexts["setting-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "the Setting's page")
        XCTAssertTrue(summary.label.range(of: #"\bvisits?\b"#, options: .regularExpression) != nil, "with its count (\(summary.label))")
        XCTAssertTrue(text(app, matching: "penguins").exists, "with its memos")
        shot(app, "setting")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(link.waitForExistence(timeout: 10), "Back returns to the event")
    }

    /// The door opens a Setting directly (for design_shots).
    func testSettingDoor() {
        let app = launch(["APP_START_SETTING": "Denver Zoo"])
        XCTAssertTrue(app.staticTexts["setting-summary"].waitForExistence(timeout: 25))
        shot(app, "setting-door")
    }
}
