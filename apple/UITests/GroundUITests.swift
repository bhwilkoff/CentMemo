import XCTest

/// The person's color (Decision 060): choosing one in Settings is saved to the
/// account and comes back after a relaunch; the test restores aqua.
final class GroundUITests: DeviceTestCase {
    func testChooseColorPersists() {
        let app = launch(["APP_START_TAB": "settings"])
        let sky = app.buttons["ground-sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 25), "color picker")
        sky.tap()
        XCTAssertTrue(sky.isSelected, "sky selected")
        shot(app, "ground-sky")
        sleep(2)
        app.terminate()
        let again = launch(["APP_START_TAB": "settings"])
        let sky2 = again.buttons["ground-sky"]
        XCTAssertTrue(sky2.waitForExistence(timeout: 25))
        XCTAssertTrue(sky2.isSelected, "sky still selected after relaunch")
        again.buttons["ground-aqua"].tap()
        sleep(2)
        XCTAssertTrue(again.buttons["ground-aqua"].isSelected, "restored aqua")
    }
}
