import XCTest

/// The empty state, seen with a real empty account: the synthetic stranger has
/// no transactions (tools/test_rls.mjs keeps it that way). Unexamined must say
/// so and offer the next action, import (universal-feature-states).
final class EmptyStateUITests: DeviceTestCase {
    func testEmptyAccountOffersImport() {
        let runner = ProcessInfo.processInfo.environment
        guard let email = runner["APP_TEST_STRANGER_EMAIL"], let password = runner["APP_TEST_STRANGER_PASSWORD"] else {
            XCTFail("stranger credentials not handed to the runner"); return
        }
        let app = launch(["APP_TEST_EMAIL": email, "APP_TEST_PASSWORD": password, "APP_START_TAB": "unexamined"])
        XCTAssertTrue(app.staticTexts["No transactions yet"].waitForExistence(timeout: 30), "empty Unexamined says so")
        XCTAssertTrue(text(app, matching: "Import an Apple Card export").exists, "and says what to do")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Import'")).firstMatch.exists, "with the import action")
        shot(app, "empty-unexamined")
        app.terminate()

        // Control: the owner (back on the next launch) sees purchases, not the empty state.
        let owner = launch(["APP_START_TAB": "unexamined"])
        XCTAssertTrue(owner.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting for a memo'")).firstMatch.waitForExistence(timeout: 30),
                      "the owner sees purchases again (the door switched back)")
        XCTAssertFalse(owner.staticTexts["No transactions yet"].exists)
    }
}
