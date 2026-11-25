import XCTest

/// Writing the story: a memo saved through the UI comes back from the server,
/// and removing it leaves the purchase unexamined again (data left as found).
final class MemoUITests: DeviceTestCase {
    func testDetailShowsMemoAndValues() {
        let app = launch(["APP_START_ITEM": Fixture.withMemo])
        XCTAssertTrue(text(app, matching: Fixture.withMemoTitle).waitForExistence(timeout: 25))
        // The editor reports its text as a value (its label is "Memo").
        let editor = app.textViews["memo-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "memo editor")
        XCTAssertTrue((editor.value as? String ?? "").contains("penguins"), "memo text")
        // Value chips sit below the fold; a Form draws rows only as they scroll in.
        let chip = app.buttons["Time with my kids"]
        for _ in 0..<4 where !chip.isHittable { app.swipeUp() }
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "value chip")
        shot(app, "detail-with-memo")
    }

    func testWriteThenRemoveMemo() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined])
        let editor = app.textViews["memo-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 25), "memo editor")
        let note = "UI test memo \(Int(Date().timeIntervalSince1970))"
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
        editor.typeText(note)
        // Save is in the navigation bar, reachable with the keyboard up.
        let save = app.buttons["save-memo"]
        XCTAssertTrue(save.waitForExistence(timeout: 5) && save.isHittable, "Save reachable while writing")
        save.tap()
        XCTAssertTrue(app.staticTexts["memo-status"].waitForExistence(timeout: 15), "save status")
        XCTAssertEqual(app.staticTexts["memo-status"].label, "Saved.")
        shot(app, "memo-saved")
        // The memo can be shared at once, without leaving the page and coming back.
        let more = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'More' OR identifier == 'more'")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "the ⋯ menu")
        more.tap()
        XCTAssertTrue(app.buttons["Make a link"].firstMatch.waitForExistence(timeout: 10), "Make a link, right after Save")
        XCTAssertTrue(app.buttons["Share"].firstMatch.exists, "Share, right after Save")
        shot(app, "memo-saved-more")

        // Relaunch: the memo is read back from the server, not the screen's memory.
        app.terminate()
        let again = launch(["APP_START_ITEM": Fixture.unexamined])
        let editor2 = again.textViews["memo-editor"]
        XCTAssertTrue(editor2.waitForExistence(timeout: 25))
        XCTAssertTrue((editor2.value as? String ?? "").contains(note), "memo survives a relaunch")

        // Put it back: clear and save.
        // Clear it by selecting, not by placing a caret: taps put the caret at the
        // start or mid-text on the iPhone 12 (seen in frames), and the edit menu's
        // "Select All" did not reliably appear. A triple tap selects the paragraph.
        editor2.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        editor2.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual((editor2.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "", "memo cleared")
        again.buttons["save-memo"].tap()
        XCTAssertTrue(again.staticTexts["memo-status"].waitForExistence(timeout: 15))
        XCTAssertEqual(again.staticTexts["memo-status"].label, "Memo removed.")
        shot(again, "memo-removed")
    }
}
