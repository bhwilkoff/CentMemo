import XCTest

/// Attach a photo by reference: the native picker returns the asset's
/// identifier, CentMemo records only that, and the tile shows the photo or
/// says why it cannot. The Photos access prompt is answered "Don't Allow" on
/// purpose: the bench iPhone is the owner's phone, and the denied path must
/// still record the reference and explain itself. Removes what it attached.
final class PhotoAttachUITests: DeviceTestCase {
    func testAttachByReferenceThenRemove() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined])
        XCTAssertTrue(app.textViews["memo-editor"].waitForExistence(timeout: 30), "the purchase opened")
        let springboardEarly = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Meaningful only while access is undecided: once answered, iOS never asks again.
        let early = springboardEarly.buttons["Don’t Allow"].firstMatch
        if early.waitForExistence(timeout: 3) {
            XCTFail("a Photos prompt appeared before the person asked to add a photo")
            early.tap()
        }
        // The Form renders lazily: the Photos section exists only once scrolled near.
        let add = app.buttons["add-photo"]
        let form = app.collectionViews.firstMatch
        for _ in 0..<6 where !add.exists { form.swipeUp(velocity: .slow); sleep(1) }
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Add a photo")
        shot(app, "photos-section")
        add.tap()
        // Access is asked only now, at the moment of intent. Declined on purpose.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don’t Allow"].firstMatch
        if deny.waitForExistence(timeout: 8) { deny.tap() }

        // The picker is a remote view; its photos surface as images in the app's tree.
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo' OR label CONTAINS[c] 'photo,'")).firstMatch
        guard photo.waitForExistence(timeout: 15) else {
            shot(app, "picker-no-photo")
            XCTFail("no photo found in the picker (library empty, or picker not inspectable)")
            return
        }
        shot(app, "picker-open")
        photo.tap()

        // W8: the photo stands in the memo in its style (Plate first).
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'memo-photo-'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "the photo stands in the memo")
        shot(app, "photo-attached")

        // Item 10: the menu offers a copy in CentMemo. With Photos access declined
        // (as here) CentMemo can't read the photo, and says so instead of failing quietly.
        tile.press(forDuration: 1.2)
        let keep = app.buttons["Keep a copy in CentMemo"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "context menu offers a copy in CentMemo")
        keep.tap()
        let honest = app.staticTexts["To keep a copy, allow CentMemo to see your photos in Settings, then try again."]
        let kept = app.descendants(matching: .any)["A copy is kept in CentMemo"]
        XCTAssertTrue(honest.waitForExistence(timeout: 15) || kept.waitForExistence(timeout: 1), "the copy is kept, or CentMemo says why not")
        shot(app, "photo-copy")

        tile.press(forDuration: 1.2)
        let remove = app.buttons["Remove from this memo"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "context menu offers removal")
        remove.tap()
        XCTAssertTrue(tile.waitForNonExistence(timeout: 10), "the attachment is gone")
    }
}
