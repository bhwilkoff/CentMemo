import XCTest

/// A read-only look around Apple Wallet on Ben's own phone (his request,
/// 2026-11-22): which fields Wallet shows for an Apple Card purchase (a place,
/// a map, an address, a category) that CentMemo might also show. It opens the
/// Apple Card and a few purchases, records each screen's accessibility labels as
/// text, and goes back. It never taps anything that moves money or changes a card,
/// and never launches CentMemo. Runs only from tools/wallet_tour.py (WALLET_TOUR=1).
final class WalletTourUITests: XCTestCase {
    /// Never tapped, whatever else happens: anything that could move money, change
    /// a card, or reveal card numbers.
    static let forbidden = try! NSRegularExpression(
        pattern: "pay|send|request|transfer|add money|withdraw|lock|unlock|report|dispute|delete|remove|card number|card details|cancel|freeze|apply|schedule|set up|turn on|turn off|share|contact|call|message|install|plan|statement",
        options: .caseInsensitive)

    private func safe(_ e: XCUIElement) -> Bool {
        let l = e.label
        return !l.isEmpty && Self.forbidden.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) == nil
    }

    private func record(_ app: XCUIApplication, _ name: String) {
        sleep(3)  // let the screen settle; the runner photographs the inner display meanwhile
        let a = XCTAttachment(string: app.debugDescription)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func back(_ app: XCUIApplication) {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists, b.isHittable, safe(b) { b.tap() } else { app.swipeRight() }
        sleep(2)
    }

    func testLookAround() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WALLET_TOUR"] == "1", "run by tools/wallet_tour.py only")
        let wallet = XCUIApplication(bundleIdentifier: "com.apple.Passbook")
        wallet.launch()
        record(wallet, "01-wallet")

        let card = wallet.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Apple Card'")).firstMatch
        guard card.waitForExistence(timeout: 10), card.isHittable, safe(card) else {
            record(wallet, "no-apple-card-found")
            return
        }
        card.tap()
        record(wallet, "02-apple-card")

        // Purchases are the cells Wallet names "transaction" (the first run opened Card
        // Balance, another row that shows an amount). Open up to five, by label, so a
        // list that redraws after going back never hands us a stale element.
        var opened = 0
        var seen = Set<String>()
        for _ in 0..<4 where opened < 5 {
            let labels = wallet.cells.matching(identifier: "transaction").allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable && safe($0) }.map { $0.label }
            for label in labels where opened < 5 && !seen.contains(label) {
                seen.insert(label)
                let row = wallet.cells.matching(identifier: "transaction").matching(NSPredicate(format: "label == %@", label)).firstMatch
                guard row.exists, row.isHittable else { continue }
                row.tap()
                record(wallet, String(format: "03-purchase-%02d", opened))
                wallet.swipeUp()
                record(wallet, String(format: "03-purchase-%02d-lower", opened))
                opened += 1
                back(wallet)
            }
            if opened < 5 { wallet.swipeUp(); sleep(1) }
        }
        record(wallet, "04-end")
        wallet.terminate()
    }
}
