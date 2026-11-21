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
        try await APIClient.shared.deleteAccount()
        isSignedIn = false
        email = nil
    }

    /// Called when a request finds the session gone.
    func handle(_ error: Error) -> String {
        if case APIClient.APIError.signedOut = error {
            isSignedIn = false
        }
        return error.localizedDescription
    }
}
