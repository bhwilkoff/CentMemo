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

    /// W3 (Decision 069): no Save button; a pause sends the memo, leaving removes an emptied one.
    func testWriteThenRemoveMemo() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined])
        let editor = app.textViews["memo-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 25), "memo editor")
        XCTAssertFalse(app.buttons["save-memo"].exists, "there is no Save button")
        let note = "UI test memo \(Int(Date().timeIntervalSince1970))"
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
        editor.typeText(note)
        shot(app, "memo-written")
        // After a pause the memo is on the server: Share appears, on this page.
        XCTAssertTrue(app.buttons["share-memo"].waitForExistence(timeout: 20), "Share, once the memo has sent itself")
        XCTAssertFalse(app.staticTexts["memo-unsent"].exists, "no warning when it was sent")
        shot(app, "memo-sent")

        // Relaunch: the memo is read back from the server, not the screen's memory.
        app.terminate()
        let again = launch(["APP_START_ITEM": Fixture.unexamined])
        let editor2 = again.textViews["memo-editor"]
        XCTAssertTrue(editor2.waitForExistence(timeout: 25))
        XCTAssertTrue((editor2.value as? String ?? "").contains(note), "memo survives a relaunch")

        // Put it back: clear it and leave the page, which removes it.
        clear(editor2, note)
        XCTAssertEqual((editor2.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "", "memo cleared")
        again.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(3)
        again.terminate()
        let third = launch(["APP_START_ITEM": Fixture.unexamined])
        let editor3 = third.textViews["memo-editor"]
        XCTAssertTrue(editor3.waitForExistence(timeout: 25))
        XCTAssertEqual((editor3.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "", "the emptied memo was removed on leaving")
        shot(third, "memo-removed")
    }

    /// W4: styles from the format bar reach the server as Markdown, and come off again.
    func testStyleAMemo() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined, "APP_SHOW_MARKDOWN": "1"])
        let editor = app.textViews["memo-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 25), "memo editor")
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
        XCTAssertTrue(app.buttons["format-quote"].waitForExistence(timeout: 5) && app.buttons["format-quote"].isHittable, "the whole format bar rides the keyboard")
        XCTAssertTrue(app.buttons["Done"].firstMatch.isHittable, "with Done in reach")
        XCTAssertFalse(app.buttons["Underline"].exists, "no underline")
        app.buttons["format-heading"].tap()
        editor.typeText("Sunday\nWe went, ")
        app.buttons["format-bold"].tap()
        editor.typeText("all of us")
        app.buttons["format-bold"].tap()
        editor.typeText("\n")
        app.buttons["format-list"].tap()
        editor.typeText("penguins\nseals")
        shot(app, "memo-styled")
        let stored = app.staticTexts["memo-markdown"]
        let want = "# Sunday\nWe went, **all of us**\n- penguins\n- seals"
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, stored.label != want { sleep(1) }
        XCTAssertEqual(stored.label, want, "the server holds the styles as Markdown")
        // Relaunch: the styles come back from the server into the editor.
        app.terminate()
        let again = launch(["APP_START_ITEM": Fixture.unexamined, "APP_SHOW_MARKDOWN": "1"])
        let e2 = again.textViews["memo-editor"]
        XCTAssertTrue(e2.waitForExistence(timeout: 25))
        XCTAssertTrue((e2.value as? String ?? "").contains("• penguins"), "the list is drawn with bullets")
        shot(again, "memo-styled-reopened")
        clear(e2, e2.value as? String ?? "")
        again.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(3)
    }

    /// W3: written with no network, the memo stays on the device, says so, and is sent
    /// when the app opens with a network again.
    func testOfflineMemoIsKeptThenSent() {
        // Reads work; every write fails, as on a connection that drops.
        let offline = launch(["APP_START_ITEM": Fixture.unexamined, "APP_FAIL_NETWORK": "writes"])
        let e1 = offline.textViews["memo-editor"]
        XCTAssertTrue(e1.waitForExistence(timeout: 25), "memo editor offline")
        let note = "Offline memo \(Int(Date().timeIntervalSince1970))"
        e1.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
        e1.typeText(note)
        let warning = offline.descendants(matching: .any)["memo-unsent"]
        XCTAssertTrue(warning.waitForExistence(timeout: 15), "it says the memo is only on this device")
        shot(offline, "memo-unsent")
        offline.terminate()

        let back = launch(["APP_START_ITEM": Fixture.unexamined])
        let e2 = back.textViews["memo-editor"]
        XCTAssertTrue(e2.waitForExistence(timeout: 25))
        XCTAssertTrue((e2.value as? String ?? "").contains(note), "the kept memo is on the page")
        sleep(4)
        XCTAssertFalse(back.descendants(matching: .any)["memo-unsent"].exists, "and was sent")
        // Clean up: clear and leave.
        clear(e2, note)
        back.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(3)
    }

    /// The caret at the end (a tap low and right), then one delete per character: triple
    /// taps selected nothing on the simulator and only a word on the iPhone 12.
    /// Repeats, since a tap can land the caret short of the end.
    private func clear(_ editor: XCUIElement, _ words: String) {
        for _ in 0..<4 {
            let left = editor.value as? String ?? words
            if left.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
            editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: left.count + 2))
        }
    }
}
