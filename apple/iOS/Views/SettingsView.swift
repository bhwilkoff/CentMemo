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

    @Environment(\.horizontalSizeClass) private var width
    @State private var pane: SettingsPane = .look

    var body: some View {
        Group {
            if width == .regular {
                // The open Duo (Ben, 2026-11-23): "work like a regular sidebar with the
                // actual settings showing on the right", one stack for the screen and
                // the list as a plain column, as TwoPane (Ear Drama iOS-DESIGN 3.6e).
                HStack(spacing: 0) {
                    List {
                        ForEach(SettingsPane.allCases) { p in
                            Button { pane = p; UISelectionFeedbackGenerator().selectionChanged() } label: {
                                Label(p.title, systemImage: p.symbol).frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(pane == p ? Color.brandSurfaceAlt : Color.clear)
                            .accessibilityAddTraits(pane == p ? .isSelected : [])
                            .accessibilityIdentifier("settings-pane-\(p.rawValue)")
                            .onGround().columnRowInsets()
                        }
                    }
                    .listStyle(.plain)
                    .frame(width: 380)
                    Divider()
                    Form {
                        section(pane)
                        if let error { Section { Text(error).foregroundStyle(Color.semanticError) } }
                    }
                    .modifier(PaneMargins(on: true))
                    .frame(maxWidth: .infinity)
                }
            } else {
                Form {
                    ForEach(SettingsPane.allCases) { p in
                        section(p)
                        if p == .account, let error { Section { Text(error).foregroundStyle(Color.semanticError) } }
                    }
                }
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

    @ViewBuilder private func section(_ p: SettingsPane) -> some View {
        switch p {
        case .look:
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
        case .themes:
            Section("Themes") {
                if values.isEmpty {
                    Text("Add a theme from any memo.").foregroundStyle(Color.brandTextMuted)
                }
                ForEach($values) { $v in
                    HStack(spacing: Spacing.s3) {
                        Capsule().fill(ThemeHue.color(v.name)).frame(width: 4, height: 22)
                        TextField("Theme", text: $v.name)
                            .onSubmit { Task { await rename(v) } }
                    }
                }
                .onDelete { idx in Task { await remove(idx) } }
            }
            // D14: Ben's starter themes the person doesn't have yet, each in the
            // color it would take.
            let held = Set(values.map { Themes.key($0.name) })
            let offered = Themes.starters.filter { !held.contains(Themes.key($0.name)) }
            if !offered.isEmpty {
                Section("Starter themes") {
                    ForEach(offered, id: \.name) { s in
                        HStack {
                            StarterThemeLabel(starter: s, color: Themes.nextColor(joining: values, name: s.name))
                            Spacer()
                            Button("Add") { Task { await addStarter(s) } }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("add-starter-\(s.color)")
                        }
                    }
                }
            }
        case .moneyIn:
            Section {
                ImportButton()
                // Ben: "share the documented path for each of the csv pathways to
                // allow for easier import." Same words as the web's Import page.
                DisclosureGroup("Where to get a CSV") {
                    ForEach(ExportPath.all, id: \.name) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(TypeRamp.bodyStrong)
                            Text(p.steps).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                    }
                }
                .accessibilityIdentifier("export-paths")
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
                    Text("CentMemo reads your Apple Card, Apple Cash, and Savings accounts and transactions and keeps them in your CentMemo account, so you can write memos on any device. \(ConnectorPolicy.walletDisclosure) [Privacy](https://centmemo.com/privacy/)")
                }
            }
        case .claude:
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
        case .account:
            Section("Account") {
                if let email = session.email { LabeledContent("Signed in as", value: email) }
                Button("Sign out") { Task { await session.signOut() } }
                Button("Delete account", role: .destructive) { confirmDelete = true }
            }
        case .about:
            Section {
                Link("Privacy", destination: URL(string: "https://centmemo.com/privacy/")!)
                Link("Terms", destination: URL(string: "https://centmemo.com/terms/")!)
            }
        }
    }

    private func load() async {
        do { values = try await APIClient.shared.values(); error = nil } catch { self.error = session.handle(error) }
    }
    private func addStarter(_ s: Themes.Starter) async {
        do {
            _ = try await APIClient.shared.addValue(s.name)
            values = try await APIClient.shared.values()
            session.didChangeData()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { self.error = session.handle(error) }
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

/// The Settings sidebar's sections at regular width; compact width shows them all in one list.
enum SettingsPane: String, CaseIterable, Identifiable {
    case look, themes, moneyIn, claude, account, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .look: "Ground"
        case .themes: "Themes"
        case .moneyIn: "Money in"
        case .claude: "Connect Claude"
        case .account: "Account"
        case .about: "Privacy and terms"
        }
    }
    var symbol: String {
        switch self {
        case .look: "paintpalette"
        case .themes: "tag"
        case .moneyIn: "tray.and.arrow.down"
        case .claude: "link"
        case .account: "person.crop.circle"
        case .about: "hand.raised"
        }
    }
}

/// Each source's documented CSV export path (docs/research/p2p-csv-export-paths.md).
struct ExportPath {
    let name: String, steps: String
    static let all = [
        ExportPath(name: "Apple Card", steps: "In Wallet, open Apple Card, then Card Balance, then Export Transactions (CSV). Or export from card.apple.com."),
        ExportPath(name: "Venmo", steps: "In Venmo, tap Me, then the gear, then Statements. Pick a month and download it, once for each month you want."),
        ExportPath(name: "PayPal", steps: "On paypal.com (the app can't export): open Activity, tap the download icon, choose Custom, pick up to 12 months and CSV. Big reports can take a while; PayPal emails you."),
        ExportPath(name: "Cash App", steps: "On cash.app/account (the app gives PDFs only): open Activity and tap the CSV button next to search."),
    ]
}

/// Picks an Apple Card CSV export with the system file importer and imports
/// it through the same idempotent path as the web (Decision 057).
@Observable
final class ImportStatus {
    static let shared = ImportStatus()
    var text: String?
}

struct ImportButton: View {
    @Environment(SessionStore.self) private var session
    @State private var picking = false
    /// The latest import's result outlives this view: Settings rebuilds its rows
    /// while an import runs, and the answer must still appear when it arrives.
    private var status = ImportStatus.shared
    private var result: String? {
        get { status.text }
        nonmutating set { status.text = newValue }
    }
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Button(working ? "Importing…" : "Import a CSV") { picking = true }.disabled(working)
            if let result { Text(result).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted).accessibilityIdentifier("import-result") }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .plainText]) { picked in
            Task { await importFile(picked) }
        }
        #if DEBUG
        // DEBUG door APP_IMPORT_SAMPLE=1: the same import, fed a three-row Apple Card
        // export, so a device run needs no Files picker (ImportUITests).
        .task {
            // Once per launch: a view's task can start again before the first reports.
            let door = ProcessInfo.processInfo.environment["APP_IMPORT_SAMPLE"]
            if let door, !Self.sampleImported {
                Self.sampleImported = true
                await importText(door == "venmo" ? Self.venmoSample : Self.sample, filename: "sample.csv")
            }
        }
        #endif
    }

    #if DEBUG
    static var sampleImported = false
    /// tests/fixtures/venmo-sample.csv, word for word.
    static let venmoSample = #"""
    Account Statement - (@sample-person) ,,,,,,,,,,,,,,,,,,,,,
    Account Activity,,,,,,,,,,,,,,,,,,,,,
    ,ID,Datetime,Type,Status,Note,From,To,Amount (total),Amount (tip),Amount (tax),Amount (fee),Tax Rate,Tax Exempt,Funding Source,Destination,Beginning Balance,Ending Balance,Statement Period Venmo Fees,Terminal Location,Year to Date Venmo Fees,Disclaimer
    ,,,,,,,,,,,,,,,,$12.50,,,,,
    ,3912345678901234567,2026-11-03T18:33:12,Payment,Complete,"Pizza night 🍕, my half",Sample Person,Alex Rivera,- $18.50,,0,,0,,Apple Card,,,,,Venmo,,
    ,3912345678901234568,2026-11-05T09:01:44,Payment,Complete,Concert tickets,Jordan Lee,Sample Person,+ $40.00,,0,,0,,,Venmo balance,,,,Venmo,,
    ,3912345678901234569,2026-11-09T21:10:02,Standard Transfer,Issued,,,,"- $1,021.50",,0,,0,,,Bank,,,,Venmo,,
    ,,,,,,,,,,,,,,,,,$12.50,$0.00,,$0.00,
    ,,,,,,,,,,,,,,,,,,,,,"In case of errors or questions about your
    electronic transfers, contact us."
    """#
    static let sample = """
    Transaction Date,Clearing Date,Description,Merchant,Category,Type,Amount (USD),Purchased By
    11/18/2026,11/19/2026,"BLUE PAN PIZZA 3930 W 38TH AVE DENVER 80212 CO USA",Blue Pan Pizza,Restaurants,Purchase,64.37,Sample Person
    11/16/2026,11/17/2026,"DENVER ZOO 2300 STEELE ST DENVER 80205 CO USA",Denver Zoo,Entertainment,Purchase,82.00,Sample Person
    11/14/2026,,"APPLE.COM/BILL ONE APPLE PARK WAY 866-712-7753 95014 CA USA",Apple Services,Other,Purchase,9.99,Sample Person
    """
    #endif

    private func importFile(_ picked: Result<URL, Error>) async {
        do {
            let url = try picked.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            await importText(try String(contentsOf: url, encoding: .utf8), filename: url.lastPathComponent)
        } catch {
            result = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func importText(_ text: String, filename: String) async {
        working = true
        defer { working = false }
        do {
            let (kind, rows) = try Money.parseAnyExport(text)
            let r = try await APIClient.shared.importExport(kind, rows, filename: filename)
            result = "\(kind.displayName): \(r.inserted) new" + (r.skipped > 0 ? ", \(r.skipped) already in CentMemo." : ".")
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
        // Real Wallet data never syncs into a synthetic account (it once did, from a
        // test build left signed in on a personal phone, 2026-11-22).
        if finance is FinanceKitSource, SessionStore.isSynthetic(session.email) {
            result = "This is a test account. Sign out and sign in with Apple to connect your Wallet."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        do {
            guard try await finance.requestAccess() else {
                result = "Apple Wallet access wasn't allowed. You can change this in Settings, Privacy & Security, Financial Data."
                return
            }
            let changes = try await finance.changes(since: Shared.financeToken(tokenKey))
            let r = try await APIClient.shared.syncFinance(changes)
            if let token = changes.newToken { Shared.setFinanceToken(token, tokenKey) }
            if finance is FinanceKitSource { FinanceBackgroundSync.enable() }
            result = "Synced \(r.inserted) event\(r.inserted == 1 ? "" : "s") from \(changes.accounts.count) account\(changes.accounts.count == 1 ? "" : "s")."
            session.didChangeData()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            result = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
#endif
