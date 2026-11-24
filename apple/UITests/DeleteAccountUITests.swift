import XCTest

/// Deletes the account signed in on this phone, for real. It never runs by
/// itself: CENTMEMO_DELETE_REAL=1, with the person's own say-so each time
/// (Ben's, 2026-11-24). It sends no test sign-in.
final class DeleteAccountUITests: DeviceTestCase {
    func testDeleteAccount() throws {
        guard ProcessInfo.processInfo.environment["CENTMEMO_DELETE_REAL"] == "1" else {
            throw XCTSkip("deletes a real account; set CENTMEMO_DELETE_REAL=1 with the person's say-so")
        }
        let app = XCUIApplication()
        app.launchEnvironment = ["APP_MUTE": "1", "APP_START_TAB": "settings", "APP_START_PANE": "account"]
        app.launch()
        let button = app.buttons["Delete account"]
        if !button.waitForExistence(timeout: 15) { reach(app, button, swipes: 14) }
        XCTAssertTrue(button.exists, "signed in, with Delete account in Settings")
        guard button.exists else { return }
        XCTAssertFalse(text(app, matching: "test-.*@centmemo\\.com|review@centmemo\\.com").exists, "not a test account")
        shot(app, "delete-1-settings")
        // The way back works first.
        button.tap()
        let keep = app.alerts.buttons["Keep my account"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "a visible way back")
        shot(app, "delete-2-alert")
        guard keep.exists else { return }
        keep.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5), "still signed in")
        button.tap()
        let really = app.alerts.buttons["Delete everything, permanently"]
        XCTAssertTrue(really.waitForExistence(timeout: 5))
        really.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in with Apple'")).firstMatch.waitForExistence(timeout: 30),
                      "deleted: the sign-in screen")
        shot(app, "delete-3-signed-out")
    }
}
