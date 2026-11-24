import XCTest

/// Connect Apple Wallet with the DEBUG sample source (APP_SAMPLE_FINANCE=1):
/// the explanation shows before access is asked (FinanceKit Addendum 3.3), the
/// sync writes rows, a second sync adds no duplicates (Decision 057), and the
/// sample account is removed afterward so the data is left as found.
final class WalletSyncUITests: DeviceTestCase {
    func testSampleSyncIsIdempotent() {
        let app = launch(["APP_START_TAB": "settings", "APP_SAMPLE_FINANCE": "1"])
        let button = app.buttons["wallet-sync"]
        XCTAssertTrue(text(app, matching: "^Color$").waitForExistence(timeout: 25))
        XCTAssertTrue(reach(app, button), "Connect Apple Wallet")
        XCTAssertTrue(reach(app, text(app, matching: "Claude never sees them"), swipes: 2), "disclosure shown before access is asked")
        button.tap()
        let result = app.staticTexts["wallet-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        XCTAssertTrue(result.label.hasPrefix("4 new or changed events from 2 accounts"), result.label)
        shot(app, "wallet-synced")
        button.tap()
        sleep(3)
        XCTAssertTrue(result.label.hasPrefix("4 new or changed events"), "upsert, not duplicate: \(result.label)")
        XCTAssertTrue(removeSampleAccount(), "sample account removed")
    }

    /// Deletes the sample FinanceKit account (its transactions cascade) as the
    /// synthetic owner, through the same REST API the app uses.
    private func removeSampleAccount() -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["APP_TEST_EMAIL"], let password = env["APP_TEST_PASSWORD"] else { return false }
        let base = "https://qucsmmazfalbyduxlavl.supabase.co", key = "sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT"
        func call(_ req: URLRequest) -> (Int, Data) {
            let done = expectation(description: "http"); var out = (0, Data())
            URLSession.shared.dataTask(with: req) { d, r, _ in out = ((r as? HTTPURLResponse)?.statusCode ?? 0, d ?? Data()); done.fulfill() }.resume()
            wait(for: [done], timeout: 20); return out
        }
        var signIn = URLRequest(url: URL(string: base + "/auth/v1/token?grant_type=password")!)
        signIn.httpMethod = "POST"; signIn.setValue(key, forHTTPHeaderField: "apikey"); signIn.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signIn.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (_, body) = call(signIn)
        guard let token = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["access_token"] as? String else { return false }
        var del = URLRequest(url: URL(string: base + "/rest/v1/accounts?source=eq.financekit&source_id=in.(sample-card,sample-cash)")!)
        del.httpMethod = "DELETE"; del.setValue(key, forHTTPHeaderField: "apikey"); del.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        return (200..<300).contains(call(del).0)
    }
}
