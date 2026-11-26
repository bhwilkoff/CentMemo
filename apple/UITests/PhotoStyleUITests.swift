import XCTest

/// W8 (Decision 069): a photo stands in the memo in the style the person chooses, with
/// their words under it; the style and words come back after a relaunch. Removes it after.
final class PhotoStyleUITests: DeviceTestCase {
    func testStyleAndCaptionAPhoto() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined, "APP_ATTACH_SAMPLE_PHOTO": "1"])
        XCTAssertTrue(app.textViews["memo-editor"].waitForExistence(timeout: 25), "memo page")
        let plate = app.descendants(matching: .any)["memo-photo-plate"]
        XCTAssertTrue(reach(app, plate), "the photo stands in the memo as a plate")
        sleep(2)
        shot(app, "photo-plate")

        plate.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Mounted"].waitForExistence(timeout: 5), "styles in the photo's menu")
        app.buttons["Mounted"].tap()
        let mounted = app.descendants(matching: .any)["memo-photo-mounted"]
        XCTAssertTrue(mounted.waitForExistence(timeout: 10), "mounted")
        mounted.press(forDuration: 1.2)
        app.buttons["Add words under it"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("The meadow by the north gate")
        app.alerts.buttons["Done"].tap()
        XCTAssertTrue(text(app, matching: "The meadow by the north gate").waitForExistence(timeout: 10), "the words under it")
        sleep(2)
        shot(app, "photo-mounted")

        app.terminate()
        let again = launch(["APP_START_ITEM": Fixture.unexamined])
        XCTAssertTrue(again.textViews["memo-editor"].waitForExistence(timeout: 25))
        let back = again.descendants(matching: .any)["memo-photo-mounted"]
        XCTAssertTrue(reach(again, back), "still mounted after a relaunch")
        XCTAssertTrue(text(again, matching: "The meadow by the north gate").exists, "with its words")
        back.press(forDuration: 1.2)
        again.buttons["Strip"].tap()
        XCTAssertTrue(again.descendants(matching: .any)["memo-photo-strip"].waitForExistence(timeout: 10), "strip")
        sleep(2)
        shot(again, "photo-strip")
        let strip = again.descendants(matching: .any)["memo-photo-strip"]
        strip.press(forDuration: 1.2)
        again.buttons["Remove from this memo"].tap()
        XCTAssertTrue(strip.waitForNonExistence(timeout: 10), "removed")
    }
}
