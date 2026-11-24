import XCTest

/// Shared launch and screenshot helpers (from Ear Drama's tap tier). Every
/// launch signs the SYNTHETIC test owner in through the DEBUG door, with the
/// sign-in handed over by tools/ios_uitest.py as TEST_RUNNER_APP_TEST_*; tests
/// that change data put it back before they end.
@MainActor class DeviceTestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        declineSystemPrompt(wait: 1)  // one left by an earlier test covers every test after it
    }

    /// Declines a system permission prompt: a test never grants access on a phone.
    @discardableResult func declineSystemPrompt(wait: TimeInterval) -> Bool {
        let no = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons
            .matching(NSPredicate(format: "label IN {'Not Now', 'Don’t Allow', \"Don't Allow\"}")).firstMatch
        guard no.waitForExistence(timeout: wait) else { return false }
        no.tap()
        return true
    }

    func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        let runner = ProcessInfo.processInfo.environment
        var base = ["APP_MUTE": "1", "APP_SKIP_ONBOARD": "1"]
        for key in ["APP_TEST_EMAIL", "APP_TEST_PASSWORD"] { base[key] = runner[key] }
        app.launchEnvironment = base.merging(env) { $1 }
        app.launch()
        return app
    }

    func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// First element anywhere whose label matches the regex.
    func text(_ app: XCUIApplication, matching rx: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label MATCHES %@", "(?s).*(\(rx)).*")).firstMatch
    }

    /// Settings is a lazy list: a row below the fold does not exist until scrolled to.
    @discardableResult func reach(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 10) -> Bool {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<swipes where !element.exists { app.swipeUp(velocity: .slow); sleep(1) }
        return element.exists
    }

    /// A section by name: the tab bar on iPhone, a sidebar item on iPad.
    func openTab(_ app: XCUIApplication, _ name: String) {
        let bar = app.tabBars.buttons[name]
        if bar.waitForExistence(timeout: 5) { bar.tap(); return }
        app.buttons[name].firstMatch.tap()
    }
}

/// Synthetic purchases the tests open (tools/seed_demo.mjs).
enum Fixture {
    /// Has a memo and two values.
    static let withMemo = "a3b8c10c-68b8-4bfe-9380-c87b7015a49d"
    static let withMemoTitle = "Denver Zoo"
    /// No memo: the memo test writes one and removes it again.
    static let unexamined = "e5626ed0-b9f2-48a0-8df7-672ae6016a40"
    static let unexaminedTitle = "King Soopers"
}
