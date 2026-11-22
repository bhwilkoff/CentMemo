import XCTest

/// What Settings offers for Apple Wallet with the real FinanceKit source (no
/// sample door): the Connect button where Wallet data exists, or the reason it
/// doesn't. Never taps Connect: the bench runs as the synthetic account, and
/// authorizing there would copy a real person's Wallet data into test data.
final class WalletAvailabilityUITests: DeviceTestCase {
    func testWalletOfferIsHonest() {
        let app = launch(["APP_START_TAB": "settings"])
        XCTAssertTrue(text(app, matching: "Ground|Connect Claude").waitForExistence(timeout: 25))
        let button = app.buttons["wallet-sync"]
        let reason = text(app, matching: "isn't on this device|isn't available here")
        let form = app.collectionViews.firstMatch
        for _ in 0..<6 where !button.exists && !reason.exists { form.swipeUp(velocity: .slow); sleep(1) }
        let offered = button.exists, explained = reason.exists
        print("WALLET-OFFER connect=\(offered) reason=\(explained)")
        XCTAssertTrue(offered != explained, "exactly one: the Connect button or the reason")
        XCTAssertFalse(text(app, matching: "Waiting on Apple").exists, "the pre-approval wording is gone")
        shot(app, "wallet-offer")
    }
}
