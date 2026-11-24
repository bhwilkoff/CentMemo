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

    /// D15: the Setting page guesses the place from the statement (Apple Maps,
    /// on the phone), the person confirms it, and can choose again.
    func testPlaceGuessConfirmAndForget() {
        let app = launch(["APP_START_SETTING": "Denver Zoo"])
        let guess = app.descendants(matching: .any)["place-guess"].firstMatch
        XCTAssertTrue(guess.waitForExistence(timeout: 30), "a guess from the statement's address")
        XCTAssertTrue(text(app, matching: "Denver Zoo").exists)
        shot(app, "place-guess")
        app.buttons["place-confirm"].tap()
        let saved = app.descendants(matching: .any)["setting-place"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15), "the confirmed place stays on the page")
        shot(app, "place-saved")
        // Every visit carries the place: the event page shows it too.
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'penguins'")).firstMatch.tap()
        let entryPlace = app.descendants(matching: .any)["entry-place"].firstMatch
        for _ in 0..<5 where !entryPlace.exists { app.swipeUp() }
        XCTAssertTrue(entryPlace.waitForExistence(timeout: 15), "the event page shows the confirmed place, under the memo")
        shot(app, "entry-place")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        saved.press(forDuration: 1.2)
        let again = app.buttons["Choose a different place"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        XCTAssertTrue(guess.waitForExistence(timeout: 30), "forgotten: the guess returns")
    }

    /// D15b: a Setting whose statement names no place ("MONTHLY INSTALLMENTS"
    /// at Apple) offers a quiet "Find on the map", then Apple's one-time
    /// location button; tapping it searches near the phone, once.
    func testFindOnTheMapNearHere() throws {
        let app = launch(["APP_START_SETTING": "Apple"])
        let find = app.buttons["place-find"]
        XCTAssertTrue(find.waitForExistence(timeout: 30), "no place words: a quiet Find on the map")
        XCTAssertFalse(app.descendants(matching: .any)["place-guess"].exists, "and no guess pushed at the person")
        find.tap()
        // The system draws LocationButton out of process, so our identifier isn't on it.
        let here = text(app, matching: "Current Location")
        XCTAssertTrue(here.waitForExistence(timeout: 10), "Apple's one-time location button")
        shot(app, "place-find")
        // A tap asks for location, and only a person grants that (the open prompt once
        // covered every later test): the search itself is checked by hand.
        guard ProcessInfo.processInfo.environment["CENTMEMO_LOCATION_OK"] == "1" else {
            throw XCTSkip("the location button is there; a person grants location, so the search is unverified")
        }
        here.tap()
        let guess = app.descendants(matching: .any)["place-guess"].firstMatch
        XCTAssertTrue(guess.waitForExistence(timeout: 30), "a guess near the phone (Apple <store>)")
        shot(app, "place-near-here")
    }

    /// The door opens a Setting directly (for design_shots).
    func testSettingDoor() {
        let app = launch(["APP_START_SETTING": "Denver Zoo"])
        XCTAssertTrue(app.staticTexts["setting-summary"].waitForExistence(timeout: 25))
        shot(app, "setting-door")
    }
}
