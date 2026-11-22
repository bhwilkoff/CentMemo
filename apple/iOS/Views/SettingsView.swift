#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// Values, money in (import, Apple Wallet), connecting Claude, and the account.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var values: [LifeValue] = []
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var copied = false
    private let finance = FinanceSources.current

    var body: some View {
        Form {
            Section("Ground") {
                HStack(spacing: Spacing.s3) {
                    ForEach(Ground.allCases) { g in
                        Button { Task { do { try await session.choose(g) } catch { self.error = session.handle(error) } } } label: {
                            VStack(spacing: Spacing.s1) {
                                Circle().fill(g.color).frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(session.ground == g ? Color.brandPrimary : Color.brandBorder,
                                                                   lineWidth: session.ground == g ? 3 : 1))
                                Text(g.name).font(TypeRamp.caption)
                                    .fontWeight(session.ground == g ? .semibold : .regular)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(g.name)
                        .accessibilityIdentifier("ground-\(g.rawValue)")
                        .accessibilityAddTraits(session.ground == g ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Section("Themes") {
                if values.isEmpty {
                    Text("Add a theme from any memo.").foregroundStyle(Color.brandTextMuted)
                }
                ForEach($values) { $v in
                    TextField("Theme", text: $v.name)
                        .onSubmit { Task { await rename(v) } }
                }
                .onDelete { idx in Task { await remove(idx) } }
            }
            Section {
                ImportButton()
                if let reason = finance.unavailableReason {
                    LabeledContent("Apple Wallet") { Text(reason).font(TypeRamp.caption).multilineTextAlignment(.trailing) }
                } else {
                    WalletSyncButton(finance: finance)
                }
            } header: {
                Text("Money in")
            } footer: {
                // FinanceKit Addendum 3.3: what is read, how it is used, and the policy,
                // shown before the person is asked for access.
                if finance.unavailableReason == nil {
                    Text("CentMemo reads your Apple Card, Apple Cash, and Savings accounts and transactions and keeps them in your CentMemo account, so you can write memos on any device. Claude never sees them. [Privacy](https://centmemo.com/privacy/)")
                }
            }
            Section {
                Text(APIClient.mcpURL).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Button(copied ? "Copied" : "Copy connector address") {
                    UIPasteboard.general.string = APIClient.mcpURL
                    copied = true
                }
            } header: {
                Text("Connect Claude")
            } footer: {
                Text("Claude can read your Narrative and memos but can never change them. In Claude, open Settings, then Connectors, then Add custom connector.")
            }
            Section("Account") {
                if let email = session.email { LabeledContent("Signed in as", value: email) }
                Button("Sign out") { Task { await session.signOut() } }
                Button("Delete account", role: .destructive) { confirmDelete = true }
            }
            if let error { Section { Text(error).foregroundStyle(Color.semanticError) } }
            Section {
                Link("Privacy", destination: URL(string: "https://centmemo.com/privacy/")!)
                Link("Terms", destination: URL(string: "https://centmemo.com/terms/")!)
            }
        }
        .grounded()
        .navigationTitle("Settings")
        // An alert, not a confirmation dialog: iOS 26 shows that dialog as a sheet with
        // only the destructive button (cancel-role buttons hidden), and a permanent
        // action needs a visible way back (seen on the iPhone 12, 2026-11-22).
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Keep my account", role: .cancel) { }
            Button("Delete everything, permanently", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("This removes every event, memo, and theme, and can't be undone.")
        }
        .task(id: session.dataVersion) { await load() }
    }

    private func load() async {
        do { values = try await APIClient.shared.values(); error = nil } catch { self.error = session.handle(error) }
    }
    private func rename(_ v: LifeValue) async {
        do { try await APIClient.shared.renameValue(v.id, to: v.name); session.didChangeData() } catch { self.error = session.handle(error) }
    }
    private func remove(_ idx: IndexSet) async {
        for i in idx {
            do { try await APIClient.shared.deleteValue(values[i].id) } catch { self.error = session.handle(error) }
        }
        session.didChangeData()
    }
    private func deleteAccount() async {
        do { try await session.deleteAccount() } catch { self.error = session.handle(error) }
    }
}

/// Picks an Apple Card CSV export with the system file importer and imports
/// it through the same idempotent path as the web (Decision 057).
struct ImportButton: View {
    @Environment(SessionStore.self) private var session
    @State private var picking = false
    @State private var result: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Button(working ? "Importing…" : "Import Apple Card export") { picking = true }.disabled(working)
            if let result { Text(result).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted) }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .plainText]) { picked in
            Task { await importFile(picked) }
        }
    }

    private func importFile(_ picked: Result<URL, Error>) async {
        working = true
        defer { working = false }
        do {
            let url = try picked.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let rows = try Money.parseAppleCardCSV(try String(contentsOf: url, encoding: .utf8))
            let r = try await APIClient.shared.importAppleCard(rows, filename: url.lastPathComponent)
            result = "\(r.inserted) new" + (r.skipped > 0 ? ", \(r.skipped) already in CentMemo." : ".")
            session.didChangeData()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            result = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}


/// Connect Apple Wallet: asks FinanceKit for access, then syncs changes since
/// the saved history token (Decision 057). DEBUG builds can use the sample
/// source (APP_SAMPLE_FINANCE=1) because the simulator and an unentitled build
/// have no Wallet data.
struct WalletSyncButton: View {
    let finance: FinanceSource
    @Environment(SessionStore.self) private var session
    @State private var working = false
    @State private var result: String?

    private var tokenKey: String { FinanceSources.tokenKey(session.email) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Button(working ? "Syncing…" : "Connect Apple Wallet") { Task { await sync() } }
                .disabled(working)
                .accessibilityIdentifier("wallet-sync")
            if let result {
                Text(result).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    .accessibilityIdentifier("wallet-result")
            }
        }
    }

    private func sync() async {
        working = true
        defer { working = false }
        do {
            guard try await finance.requestAccess() else {
                result = "Apple Wallet access wasn't allowed. You can change this in Settings, Privacy & Security, Financial Data."
                return
            }
            let changes = try await finance.changes(since: UserDefaults.standard.data(forKey: tokenKey))
            let r = try await APIClient.shared.syncFinance(changes)
            if let token = changes.newToken { UserDefaults.standard.set(token, forKey: tokenKey) }
            result = "Added \(r.inserted) event\(r.inserted == 1 ? "" : "s") from \(changes.accounts.count) account\(changes.accounts.count == 1 ? "" : "s")."
            session.didChangeData()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            result = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
#endif
