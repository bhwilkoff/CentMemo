import XCTest

/// Each tab opens signed in and draws text only that screen draws (never a
/// tab-bar label: Ear Drama's bar words once made frames pass).
final class TabSmokeUITests: DeviceTestCase {
    private func check(_ tab: String, _ rx: String) {
        let app = launch(["APP_START_TAB": tab])
        XCTAssertTrue(text(app, matching: rx).waitForExistence(timeout: 25), "\(tab): /\(rx)/")
        XCTAssertFalse(app.buttons["Sign in with Apple"].exists, "\(tab): signed out")
        shot(app, "tab-\(tab)")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testUnexamined() { check("unexamined", "waiting for a memo|Every purchase has a memo|No transactions yet") }
    func testLedger() { check("ledger", "Spent|Paid or credited") }
    func testStory() { check("story", "memos? ·|No memos here yet") }
    func testSettings() { check("settings", "Connect Claude") }

    /// The tab bar itself: every tab is reachable by tapping from Unexamined.
    func testTapThroughTabs() {
        let app = launch()
        XCTAssertTrue(text(app, matching: "waiting for a memo|Every purchase has a memo").waitForExistence(timeout: 25))
        for (tab, rx) in [("Ledger", "Spent"), ("Story", "memos? ·|No memos here yet"), ("Settings", "Connect Claude"), ("Unexamined", "waiting for a memo|Every purchase")] {
            openTab(app, tab)
            XCTAssertTrue(text(app, matching: rx).waitForExistence(timeout: 15), "after tapping \(tab): /\(rx)/")
            shot(app, "tapped-\(tab)")
        }
    }
}
