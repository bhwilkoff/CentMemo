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

    func testUnexamined() { check("unexamined", "Biggest this month|First time here|Your busiest day|A year ago you wrote|Every purchase has a memo|Nothing in your Narrative yet") }
    func testLedger() { check("ledger", "Spent|Paid or credited") }
    func testStory() { check("story", "memos? ·|No memos here yet") }
    func testSettings() { check("settings", "Connect Claude") }

    /// Settings shows the connector's public address, not the database host's.
    func testConnectorAddress() {
        let app = launch(["APP_START_TAB": "settings"])
        XCTAssertTrue(text(app, matching: "Ground|Connect Claude").waitForExistence(timeout: 25))
        let address = text(app, matching: "mcp\\.centmemo\\.com")
        let form = app.collectionViews.firstMatch
        for _ in 0..<8 where !address.exists { form.swipeUp(velocity: .slow); sleep(1) }
        XCTAssertTrue(address.exists, "Settings shows https://mcp.centmemo.com")
        XCTAssertFalse(text(app, matching: "supabase\\.co").exists, "and never the Supabase address")
        shot(app, "connector-address")
    }

    /// Settings tells where each source's CSV comes from (S1/S2).
    func testExportPaths() {
        let app = launch(["APP_START_TAB": "settings"])
        XCTAssertTrue(text(app, matching: "Ground|Connect Claude").waitForExistence(timeout: 25))
        let group = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Where to get a CSV'")).firstMatch
        let form = app.collectionViews.firstMatch
        for _ in 0..<6 where !(group.exists && group.isHittable && group.frame.maxY < app.frame.height * 0.7) { form.swipeUp(velocity: .slow); sleep(1) }
        XCTAssertTrue(group.exists, "Where to get a CSV")
        group.tap()
        XCTAssertTrue(text(app, matching: "Statements").waitForExistence(timeout: 5), "Venmo's path")
        XCTAssertTrue(text(app, matching: "cash\\.app/account").exists, "Cash App's path")
        shot(app, "export-paths")
    }

    /// The tab bar itself: every tab is reachable by tapping from Unexamined.
    func testTapThroughTabs() {
        let app = launch()
        XCTAssertTrue(text(app, matching: "Biggest this month|First time here|Your busiest day|A year ago you wrote|Every purchase has a memo").waitForExistence(timeout: 25))
        for (tab, rx) in [("Narrative", "Spent"), ("Story", "memos? ·|No memos here yet"), ("Settings", "Connect Claude"), ("Unexamined", "Biggest this month|First time here|Your busiest day|A year ago you wrote|Every purchase")] {
            openTab(app, tab)
            XCTAssertTrue(text(app, matching: rx).waitForExistence(timeout: 15), "after tapping \(tab): /\(rx)/")
            shot(app, "tapped-\(tab)")
        }
    }
}
