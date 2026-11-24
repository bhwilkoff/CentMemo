import Foundation
import Observation

/// Who is signed in, owned in one place; views read it from the environment.
/// `dataVersion` bumps after any write so every list reloads (the Android
/// lesson: key reloads on a version, never on the view's identity).
@Observable
final class SessionStore {
    private(set) var isSignedIn = APIClient.shared.isSignedIn
    private(set) var email = APIClient.shared.email
    private(set) var dataVersion = 0
    /// Cached so the first frame already wears the person's ground.
    private(set) var ground = Ground(rawValue: UserDefaults.standard.string(forKey: "ground") ?? "") ?? .aqua

    func loadGround() async {
        guard let g = try? await APIClient.shared.ground() else { return }
        setLocal(g)
    }

    func choose(_ g: Ground) async throws {
        setLocal(g)
        try await APIClient.shared.setGround(g)
    }

    private func setLocal(_ g: Ground) {
        ground = g
        UserDefaults.standard.set(g.rawValue, forKey: "ground")
    }

    func didSignIn() {
        isSignedIn = APIClient.shared.isSignedIn
        email = APIClient.shared.email
        dataVersion += 1
    }

    func didChangeData() { dataVersion += 1 }

    func signOut() async {
        await APIClient.shared.signOut()
        isSignedIn = false
        email = nil
    }

    func deleteAccount() async throws {
        let key = FinanceSources.tokenKey(email)
        try await APIClient.shared.deleteAccount()
        FinanceBackgroundSync.disable()
        Shared.setFinanceToken(nil, key)
        isSignedIn = false
        email = nil
    }

    /// The synthetic accounts the harness and reviewers use (test-*@centmemo.com,
    /// review@centmemo.com). Real Wallet data never goes into one.
    static func isSynthetic(_ email: String?) -> Bool {
        guard let e = email?.lowercased() else { return false }
        return e == "review@centmemo.com" || (e.hasPrefix("test-") && e.hasSuffix("@centmemo.com"))
    }

    /// Called when a request finds the session gone.
    func handle(_ error: Error) -> String {
        if case APIClient.APIError.signedOut = error {
            isSignedIn = false
        }
        return Self.describe(error)
    }

    /// The same words the web uses (js/app.js failed()): a dropped connection
    /// reads as offline, an unreachable server as CentMemo's, never URLSession's.
    static func describe(_ error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: return "You're offline."
            case .cancelled: return "Canceled."
            default: return "CentMemo couldn't reach its server."
            }
        }
        return error.localizedDescription
    }
}
