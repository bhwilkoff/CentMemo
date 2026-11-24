import XCTest

/// Every main screen upright (DESIGN W7): a tablet's frames otherwise come only from
/// the way it happens to be lying. Puts the device back as it was.
final class PortraitUITests: DeviceTestCase {
    func testUpright() {
        let was = XCUIDevice.shared.orientation
        XCUIDevice.shared.orientation = .portrait
        for (tab, rx) in [("unexamined", "King Soopers"), ("ledger", "Spent"), ("story", "memos?$"), ("settings", "Color")] {
            let app = launch(["APP_START_TAB": tab])
            XCTAssertTrue(text(app, matching: rx).waitForExistence(timeout: 25), tab)
            sleep(1)
            shot(app, "upright-\(tab)")
            app.terminate()
        }
        let app = launch(["APP_START_ITEM": Fixture.withMemo])
        XCTAssertTrue(text(app, matching: Fixture.withMemoTitle).waitForExistence(timeout: 25))
        shot(app, "upright-memo")
        app.terminate()
        XCUIDevice.shared.orientation = was == .unknown ? .portrait : was
    }
}
