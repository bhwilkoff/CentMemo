import XCTest

/// W5 (Decision 069): a drawing is a memo part. On the iPhone a finger draws; the
/// drawing is kept, comes back after a relaunch, and comes off again (data left as found).
final class InkUITests: DeviceTestCase {
    func testDrawKeepAndRemove() {
        let app = launch(["APP_START_ITEM": Fixture.unexamined])
        XCTAssertTrue(app.textViews["memo-editor"].waitForExistence(timeout: 25), "memo page")
        let add = app.buttons["add-ink"]
        XCTAssertTrue(reach(app, add), "Draw or write by hand")
        add.tap()
        let canvas = app.descendants(matching: .any)["ink-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "the canvas opens")
        sleep(1)
        // A loop of pencil: three strokes, as a hand would draw.
        for (a, b) in [((0.25, 0.30), (0.75, 0.32)), ((0.30, 0.40), (0.55, 0.55)), ((0.55, 0.55), (0.70, 0.38))] {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: a.0, dy: a.1))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: b.0, dy: b.1)))
        }
        shot(app, "ink-drawing")
        app.buttons["ink-done"].tap()
        let picture = app.descendants(matching: .any)["ink-picture"]
        XCTAssertTrue(picture.waitForExistence(timeout: 20), "the drawing sits in the memo")
        sleep(2)
        shot(app, "ink-kept")

        // W7: with a memo written, the drawing can go on the share card.
        let editor = app.textViews["memo-editor"]
        reach(app, editor)
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)).tap()
        editor.typeText("Drew the line at the carousel.")
        let share = app.buttons["share-memo"]
        XCTAssertTrue(share.waitForExistence(timeout: 20), "Share, once the memo has sent itself")
        share.tap()
        let offer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'share-picture-'")).firstMatch
        XCTAssertTrue(reach(app, offer, swipes: 4), "the drawing is offered for the card")
        let enabled = NSPredicate(format: "isEnabled == true")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: offer)], timeout: 20), .completed, "once it is read and checked")
        offer.tap()
        for _ in 0..<6 where !text(app, matching: "card with a picture").exists { app.swipeDown(velocity: .slow) }
        XCTAssertTrue(text(app, matching: "card with a picture: Drew the line").waitForExistence(timeout: 5), "the card carries it")
        shot(app, "share-with-drawing")
        // W7: the same drawing on a link page; made, then the memo's removal takes it away.
        app.segmentedControls["share-kind"].buttons["Link"].tap()
        let linkOffer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'share-picture-'")).firstMatch
        XCTAssertTrue(reach(app, linkOffer, swipes: 6), "the drawing is offered for the page")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: linkOffer)], timeout: 20), .completed)
        linkOffer.tap()
        XCTAssertTrue(app.webViews.images.firstMatch.waitForExistence(timeout: 10), "the page shows it, live")
        shot(app, "link-with-drawing")
        app.buttons["link-make"].tap()
        XCTAssertTrue(app.buttons["link-send"].waitForExistence(timeout: 30), "the link is made with its picture")
        let address = app.staticTexts["link-url"].label
        let code = address.components(separatedBy: "#").last ?? ""
        XCTAssertEqual(code.count, 22, "the link's address: \(address)")
        XCTAssertEqual(Self.status(of: code), 200, "its picture is public under the link's code")
        app.buttons["Done"].firstMatch.tap()
        // The memo comes off again (the test leaves the account as found).
        reach(app, editor)
        for _ in 0..<4 {
            let left = editor.value as? String ?? ""
            if left.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
            editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: left.count + 2))
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(4)
        XCTAssertNotEqual(Self.status(of: code), 200, "removing the memo took the link's picture away")

        app.terminate()
        let again = launch(["APP_START_ITEM": Fixture.unexamined])
        XCTAssertTrue(again.textViews["memo-editor"].waitForExistence(timeout: 25))
        let kept = again.descendants(matching: .any)["ink-picture"]
        XCTAssertTrue(reach(again, kept), "the drawing comes back after a relaunch")
        sleep(2)
        shot(again, "ink-reopened")
        kept.press(forDuration: 1.2)
        let remove = again.buttons["Remove from this memo"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "Remove in the drawing's menu")
        remove.tap()
        XCTAssertTrue(kept.waitForNonExistence(timeout: 15), "and it comes off")
    }

    /// The public picture's status, at a fresh address so no CDN copy answers.
    static func status(of code: String) -> Int {
        guard let url = URL(string: "https://qucsmmazfalbyduxlavl.supabase.co/storage/v1/object/public/shared/\(code)/0.jpg?probe=\(Date().timeIntervalSince1970)") else { return 0 }
        let done = DispatchSemaphore(value: 0)
        var code = 0
        URLSession.shared.dataTask(with: url) { _, r, _ in code = (r as? HTTPURLResponse)?.statusCode ?? 0; done.signal() }.resume()
        _ = done.wait(timeout: .now() + 20)
        return code
    }
}
