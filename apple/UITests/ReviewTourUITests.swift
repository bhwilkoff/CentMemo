import XCTest

/// The App Review screen recording (store-submission-playbook, "the screen
/// recording"): CentMemo's flow at a human pace on a real iPhone, recorded by
/// tools/record_review.sh with `devicectl device capture screen-record`.
/// Runs only when the recorder sets REVIEW_TOUR=1, never in the normal tier.
/// It runs as the synthetic owner with demo data. It never taps Connect
/// Apple Wallet (that would copy a real person's Wallet data into test data);
/// Sign in with Apple and the Wallet permission are the owner's own clip.
/// It leaves the data as it found it: the memo it writes is removed again.
final class ReviewTourUITests: DeviceTestCase {
    private func mark(_ s: String) { print("TOUR-MARK \(Date().timeIntervalSince1970) \(s)") }
    /// Twice a person's pace: the recorder captures a frame only every 1.7 s or so.
    private func pause(_ s: Double = 1.6) { usleep(UInt32(2 * s * 1_000_000)) }

    func testTour() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["REVIEW_TOUR"] == "1", "recorded by tools/record_review.sh only")
        let app = launch(["APP_START_TAB": "unexamined"])
        mark("launch")
        XCTAssertTrue(text(app, matching: "Biggest this month|First time here|Your busiest day|A year ago you wrote").waitForExistence(timeout: 30))
        pause(3)

        // A purchase, its memo, and a value: the core of the app.
        mark("write a memo")
        let first = app.collectionViews.firstMatch.cells.element(boundBy: 1)
        XCTAssertTrue(first.waitForExistence(timeout: 10)); first.tap(); pause()
        let editor = app.textViews["memo-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        editor.tap(); pause(0.8)
        editor.typeText("Weekly groceries. We cooked together on Sunday."); pause()
        app.buttons["Done"].firstMatch.tap(); pause(2.5)   // the written memo, on screen
        let chip = app.buttons["Great meals"]
        if chip.waitForExistence(timeout: 5) { chip.tap(); pause() }
        pause(2.5)   // the memo sends itself after a pause (W3)

        // Put it back (the tour leaves the account as it found it), off camera time kept short.
        mark("clear the memo again")
        // Focus first: with the keyboard down, the first of three taps only focuses,
        // and the triple tap selected one word (a tour left a memo behind, 2026-11-22).
        editor.tap(); pause(0.6)
        editor.tap(withNumberOfTaps: 3, numberOfTouches: 1); editor.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual((editor.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines), "", "memo cleared")
        if chip.exists, chip.isSelected { chip.tap() }
        // Leaving the page removes the emptied memo (W3).
        app.navigationBars.buttons.element(boundBy: 0).tap(); pause()

        mark("ledger"); openTab(app, "Narrative"); pause(3)
        app.collectionViews.firstMatch.swipeUp(velocity: .slow); pause(2)
        mark("story"); openTab(app, "Story"); pause(3.5)

        mark("settings"); openTab(app, "Settings"); pause(2.5)
        let form = app.collectionViews.firstMatch
        for _ in 0..<3 { form.swipeUp(velocity: .slow); pause(1.8) }   // color, values, Apple Wallet, Claude
        mark("delete account (canceled)")
        let delete = app.buttons["Delete account"]
        for _ in 0..<4 where !delete.isHittable { form.swipeUp(velocity: .slow); pause(1) }
        XCTAssertTrue(delete.isHittable); delete.tap(); pause(2.5)
        let keep = app.buttons["Keep my account"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "deletion asks first, with a way back"); keep.tap(); pause(2)
        mark("end")
    }
}
