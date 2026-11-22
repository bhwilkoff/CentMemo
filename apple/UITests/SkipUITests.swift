import XCTest

/// Skip (Decision 065) by swipe: an event leaves Unexamined, waits in the
/// Narrative's "skipped" group, and swipes back. Leaves the fixture as found.
final class SkipUITests: DeviceTestCase {
    func testSwipeSkipThenBringBack() {
        let app = launch(["APP_START_TAB": "unexamined"])
        XCTAssertTrue(text(app, matching: "waiting for a memo").waitForExistence(timeout: 30))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'King Soopers'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "King Soopers waits in Unexamined")
        reveal(row)
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "the swipe offers Skip")
        skip.tap()
        XCTAssertTrue(waitGone(row), "King Soopers left Unexamined")
        shot(app, "skipped-unexamined")

        openTab(app, "Narrative")
        let group = app.buttons.matching(NSPredicate(format: "label CONTAINS 'skipped'")).firstMatch
        // The group closes the month, below the rows: scroll to it.
        XCTAssertTrue(text(app, matching: "Spent|Paid or credited").waitForExistence(timeout: 15))
        let list = app.collectionViews.firstMatch
        // Clear of the floating glass tab bar too: a tap at the bottom edge lands on
        // the bar (it once opened Story instead of the group).
        let clearY = app.frame.height * 0.7
        for _ in 0..<14 where !(group.exists && group.isHittable && group.frame.maxY < clearY) { list.swipeUp(velocity: .slow); usleep(400_000) }
        XCTAssertTrue(group.exists, "the Narrative gathers it under \"skipped\"")
        group.tap()
        let skipped = app.buttons.matching(NSPredicate(format: "label CONTAINS 'King Soopers'")).firstMatch
        XCTAssertTrue(skipped.waitForExistence(timeout: 5))
        for _ in 0..<6 where !(skipped.isHittable && skipped.frame.maxY < clearY) { list.swipeUp(velocity: .slow); usleep(400_000) }
        reveal(skipped)
        shot(app, "narrative-after-reveal")
        let back = app.buttons["Bring back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "a skipped event swipes back")
        back.tap()
        shot(app, "brought-back")

        openTab(app, "Unexamined")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'King Soopers'")).firstMatch.waitForExistence(timeout: 15),
                      "King Soopers is back in Unexamined (fixture left as found)")
    }

    /// A partial swipe that reveals the action (a fast swipeLeft is a full swipe,
    /// which fires the action at once and leaves no button to tap).
    private func reveal(_ e: XCUIElement) {
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: e.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)))
    }

    private func waitGone(_ e: XCUIElement) -> Bool {
        for _ in 0..<20 where e.exists { usleep(250_000) }
        return !e.exists
    }
}
