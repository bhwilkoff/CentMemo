#if os(iOS)
import SwiftUI

/// Email in, six-digit code back. Every failure is shown on screen (the
/// Tidbits Sign in with Apple rejection: a silent failure reads as "nothing
/// happened" to a reviewer).
struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var code = ""
    @State private var sentTo: String?
    @State private var working = false
    @State private var error: String?
    @FocusState private var focus: Field?
    private enum Field { case email, code }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("CentMemo").font(TypeRamp.pageTitle)
                        Text("Every cent tells a story.").font(TypeRamp.sectionHeader)
                        Text("Write the memo for each purchase on your Apple Card, and see what your money says you value.")
                            .font(TypeRamp.body).foregroundStyle(Color.brandTextMuted)
                    }
                    .padding(.vertical, Spacing.s2)
                    .listRowBackground(Color.clear)
                }
                if let sentTo {
                    Section {
                        TextField("6-digit code", text: $code)
                            .textContentType(.oneTimeCode).keyboardType(.numberPad)
                            .focused($focus, equals: .code)
                        Button(working ? "Checking…" : "Sign in") { Task { await verify(sentTo) } }
                            .disabled(working || code.filter(\.isNumber).count < 6)
                        Button("Use a different email") { self.sentTo = nil; code = ""; error = nil }
                    } header: { Text("Code sent to \(sentTo)") }
                } else {
                    Section("Email") {
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .onSubmit { Task { await send() } }
                        Button(working ? "Sending…" : "Email me a sign-in code") { Task { await send() } }
                            .disabled(working || !email.contains("@"))
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(Color.semanticError) }
                }
                Section {
                    Link("Privacy", destination: URL(string: "https://centmemo.com/privacy/")!)
                    Link("Terms", destination: URL(string: "https://centmemo.com/terms/")!)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brandBackground)
        }
    }

    private func send() async {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard address.contains("@") else { error = "Enter your email address."; return }
        working = true; error = nil
        do { try await APIClient.shared.sendCode(to: address); sentTo = address; focus = .code }
        catch { self.error = error.localizedDescription; UINotificationFeedbackGenerator().notificationOccurred(.error) }
        working = false
    }

    private func verify(_ address: String) async {
        working = true; error = nil
        do { try await APIClient.shared.verify(email: address, code: code.filter(\.isNumber)); session.didSignIn() }
        catch { self.error = error.localizedDescription; UINotificationFeedbackGenerator().notificationOccurred(.error) }
        working = false
    }
}
#endif
