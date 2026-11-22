import XCTest

/// The error state on a real device (universal-feature-states): with the
/// network failed by the DEBUG door, a list says what went wrong in CentMemo's
/// words and offers Try again; without the door, the same list loads.
final class ErrorStateUITests: DeviceTestCase {
    private func check(_ mode: String, _ words: String) {
        let app = launch(["APP_START_TAB": "ledger", "APP_FAIL_NETWORK": mode])
        XCTAssertTrue(app.staticTexts[words].waitForExistence(timeout: 30), "\(mode): says \"\(words)\"")
        XCTAssertTrue(app.buttons["Try again"].exists, "\(mode): offers Try again")
        XCTAssertFalse(text(app, matching: "NSURLError|could not connect|appears to be offline").exists, "\(mode): never URLSession's words")
        shot(app, "error-\(mode)")
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts[words].waitForExistence(timeout: 15), "\(mode): retry fails the same way, still alive")
        XCTAssertEqual(app.state, .runningForeground)
        app.terminate()
    }

    func testUnreachable() { check("unreachable", "CentMemo couldn't reach its server.") }
    func testOffline() { check("offline", "You're offline.") }

    /// Control: no door, the ledger loads.
    func testNoDoorLoads() {
        let app = launch(["APP_START_TAB": "ledger"])
        XCTAssertTrue(text(app, matching: "Spent|Paid or credited").waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Try again"].exists)
    }
}
