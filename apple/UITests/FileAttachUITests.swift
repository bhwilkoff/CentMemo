import XCTest

/// Item 10: a file added to a memo is kept as a private copy and listed by
/// name. The DEBUG door APP_ATTACH_SAMPLE_FILE=1 adds a generated one-page PDF,
/// so the run needs no Files picker. Removes what it added.
final class FileAttachUITests: DeviceTestCase {
    func testFileKeptAndRemoved() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined, "APP_ATTACH_SAMPLE_FILE": "1"])
        XCTAssertTrue(app.textViews["memo-editor"].waitForExistence(timeout: 30), "the purchase opened")
        let file = app.buttons["attached-file"].firstMatch
        let form = app.collectionViews.firstMatch
        for _ in 0..<8 where !file.exists { form.swipeUp(velocity: .slow); sleep(1) }
        XCTAssertTrue(file.waitForExistence(timeout: 20), "the file is kept and listed")
        XCTAssertTrue(file.label.contains("Sample receipt.pdf"), "by its name (\(file.label))")
        let note = app.staticTexts["Files you add are kept in CentMemo, privately."]
        for _ in 0..<4 where !note.exists { form.swipeUp(velocity: .slow); sleep(1) }
        XCTAssertTrue(note.exists, "and says where it lives")
        shot(app, "file-kept")
        file.press(forDuration: 1.2)
        let remove = app.buttons["Remove from this memo"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(file.waitForNonExistence(timeout: 10), "removed, with its copy")
    }
}
