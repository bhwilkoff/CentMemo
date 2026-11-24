#if os(iOS) || os(macOS)
import SwiftUI
import AuthenticationServices
import CryptoKit

/// Sign in with Apple, the way Tidbits Trivia signs people in: no email, no
/// password, and Apple ID's two-factor sign-in, which the FinanceKit terms
/// (3.7) require on a new device. Lessons carried from Tidbits' 2.1(a)
/// rejection: the button is NOT inside a Form (it ate the tap), and every
/// failure, including a cancel, is shown on screen.
struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s6) {
            Spacer()
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("CentMemo").font(TypeRamp.pageTitle)
                Text("Every cent tells a story.").font(TypeRamp.sectionHeader)
                Text("Write the memo for each purchase on your Apple Card, and see what your money says you value.")
                    .font(TypeRamp.body).foregroundStyle(Color.brandTextMuted)
            }
            VStack(alignment: .leading, spacing: Spacing.s3) {
                SignInWithAppleButton(.signIn) { request in
                    let raw = Self.randomNonce()
                    nonce = raw
                    request.requestedScopes = [.email]
                    request.nonce = Self.sha256(raw)
                } onCompletion: { result in
                    Task { await finish(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .disabled(working)
                if working { ProgressView("Signing in…") }
                if let message {
                    Text(message).font(TypeRamp.body).foregroundStyle(Color.semanticError)
                }
            }
            Spacer()
            HStack(spacing: Spacing.s4) {
                Link("Privacy", destination: URL(string: "https://centmemo.com/privacy/")!)
                Link("Terms", destination: URL(string: "https://centmemo.com/terms/")!)
            }
            .font(TypeRamp.caption)
        }
        .padding(Spacing.s6)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
    }

    private func finish(_ result: Result<ASAuthorization, Error>) async {
        message = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                message = "Sign-in was canceled. Tap Sign in with Apple to try again."
            } else {
                message = "Apple couldn't sign you in: \(error.localizedDescription)"
            }
            Haptic.error()
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                message = "Apple didn't return a sign-in token. Try again."
                Haptic.error()
                return
            }
            working = true
            do {
                try await APIClient.shared.signInWithApple(idToken: token, nonce: nonce)
                session.didSignIn()
                Haptic.success()
            } catch {
                message = "CentMemo couldn't finish signing in: \(error.localizedDescription)"
                Haptic.error()
            }
            working = false
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
