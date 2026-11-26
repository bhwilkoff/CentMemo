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
}
