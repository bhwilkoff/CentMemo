import XCTest

/// The iPhone import, end to end on a device, as the empty stranger account:
/// the DEBUG door APP_IMPORT_SAMPLE=1 feeds the same import code a three-row
/// Apple Card export (no Files picker). The second import must add nothing
/// (Decision 057). tools/cleanup_stranger.mjs empties the account afterwards;
/// tools/test_rls.mjs fails if it is not empty.
final class ImportUITests: DeviceTestCase {
    func testImportThenReimportAddsNothing() {
        let runner = ProcessInfo.processInfo.environment
        guard let email = runner["APP_TEST_STRANGER_EMAIL"], let password = runner["APP_TEST_STRANGER_PASSWORD"] else {
            XCTFail("stranger credentials not handed to the runner"); return
        }
        let env = ["APP_TEST_EMAIL": email, "APP_TEST_PASSWORD": password, "APP_IMPORT_SAMPLE": "1"]
        // From Settings: Unexamined trades its empty state (and its import button)
        // for the list the moment the purchases arrive.
        var app = launch(env.merging(["APP_START_TAB": "settings"]) { $1 })
        let result = app.staticTexts["import-result"]
        for _ in 0..<8 where !result.exists { app.swipeUp(); sleep(1) }
        XCTAssertTrue(result.waitForExistence(timeout: 40), "the import reports back")
        XCTAssertEqual(result.label, "Apple Card: 3 new.", "three purchases imported")
        shot(app, "import-first")
        app.terminate()

        app = launch(env.merging(["APP_START_TAB": "settings"]) { $1 })
        let again = app.staticTexts["import-result"]
        for _ in 0..<8 where !again.exists { app.swipeUp(); sleep(1) }
        XCTAssertTrue(again.waitForExistence(timeout: 30), "the second import reports back")
        XCTAssertEqual(again.label, "Apple Card: 0 new, 3 already in CentMemo.", "the same export adds nothing")
        shot(app, "import-again")
    }

    /// S1 on a device: a Venmo statement through the same import lands in its own account.
    func testVenmoImport() {
        let runner = ProcessInfo.processInfo.environment
        guard let email = runner["APP_TEST_STRANGER_EMAIL"], let password = runner["APP_TEST_STRANGER_PASSWORD"] else {
            XCTFail("stranger credentials not handed to the runner"); return
        }
        let app = launch(["APP_TEST_EMAIL": email, "APP_TEST_PASSWORD": password, "APP_IMPORT_SAMPLE": "venmo", "APP_START_TAB": "settings"])
        let result = app.staticTexts["import-result"]
        for _ in 0..<8 where !result.exists { app.swipeUp(); sleep(1) }
        XCTAssertTrue(result.waitForExistence(timeout: 40), "the import reports back")
        XCTAssertEqual(result.label, "Venmo: 3 new.", "a Venmo statement is recognized and imported")
    }
}

