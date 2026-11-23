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

    /// D8: Rename saves the person's name for the place, keeps the statement's
    /// beside it, and "Use the statement name" clears it (synthetic owner only).
    func testRenameSavesAndClears() {
        let app = launch(["APP_START_SETTING": "Denver Zoo"])
        XCTAssertTrue(app.staticTexts["setting-summary"].waitForExistence(timeout: 25))
        app.buttons["setting-rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the rename field")
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        field.typeText("The Zoo")
        shot(app, "setting-rename")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(text(app, matching: "^The Zoo$").waitForExistence(timeout: 15), "the page takes the person's name")
        XCTAssertTrue(text(app, matching: "On the statement: Denver Zoo").exists, "the statement's name stays beside it")
        shot(app, "setting-renamed")
        app.buttons["setting-rename"].tap()
        let restore = app.alerts.buttons["Use the statement name"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10), "a renamed place offers its statement name back")
        restore.tap()
        XCTAssertTrue(text(app, matching: "^Denver Zoo$").waitForExistence(timeout: 15), "cleared back to the statement's name")
        XCTAssertFalse(text(app, matching: "On the statement").exists)
    }

    /// The door opens a Setting directly (for design_shots).
    func testSettingDoor() {
        let app = launch(["APP_START_SETTING": "Denver Zoo"])
        XCTAssertTrue(app.staticTexts["setting-summary"].waitForExistence(timeout: 25))
        shot(app, "setting-door")
    }
}
