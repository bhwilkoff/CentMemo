import Foundation
#if canImport(FinanceKit) && os(iOS)
import FinanceKit
#endif

/// Where transactions come from on this device. CentMemo designs against this
/// protocol so everything else can be built while Apple reviews the FinanceKit
/// entitlement (finance-app-foundations section 1).
protocol FinanceSource {
    /// Why this source can't be used right now, in words for the person; nil when it can.
    var unavailableReason: String? { get }
    func requestAccess() async throws -> Bool
    /// Changes since the saved history token (nil = everything shared).
    func changes(since token: Data?) async throws -> FinanceChanges
}

struct FinanceChanges: Sendable {
    var accounts: [FinanceAccount] = []
    var inserted: [ImportRow] = []
    var deletedSourceIDs: [String] = []
    var newToken: Data?

    /// One row per purchase, in its latest state. FinanceKit's history reports a
    /// purchase as inserted and then updated (pending, then booked), and one upsert
    /// may not touch a row twice ("ON CONFLICT DO UPDATE command cannot affect row a
    /// second time": Ben's real sync, 2026-11-22).
    func normalized() -> FinanceChanges {
        let deleted = Set(deletedSourceIDs)
        var latest: [String: ImportRow] = [:], order: [String] = []
        for row in inserted where !deleted.contains(row.sourceID) {
            if latest[row.sourceID] == nil { order.append(row.sourceID) }
            latest[row.sourceID] = row            // a later report is the newer state
        }
        var seen = Set<String>()
        return FinanceChanges(accounts: accounts.filter { seen.insert($0.sourceID).inserted },
                              inserted: order.compactMap { latest[$0] },
                              deletedSourceIDs: Array(deleted).sorted(), newToken: newToken)
    }
}

struct FinanceAccount: Sendable, Hashable {
    var sourceID: String
    var kind: String          // "asset" or "liability"
    var displayName: String
    var institution: String
    var currency: String
    var creditLimitMinor: Int?
}

enum FinanceSources {
    /// The source this build should use. FinanceKit only when the device has
    /// Wallet data AND this build carries the entitlement; calling FinanceKit
    /// otherwise terminates the app ("Process is not entitled").
    static var current: FinanceSource {
        #if DEBUG
        if ProcessInfo.processInfo.environment["APP_SAMPLE_FINANCE"] == "1" { return SampleFinanceSource() }
        #endif
        #if canImport(FinanceKit) && os(iOS)
        return FinanceKitSource()
        #else
        return UnavailableFinanceSource()
        #endif
    }

    /// The saved history token, per signed-in person.
    static func tokenKey(_ email: String?) -> String { "financeToken-" + (email ?? "anon") }
}

struct UnavailableFinanceSource: FinanceSource {
    var unavailableReason: String? {
        "Apple Wallet isn't available here. Import an Apple Card export instead."
    }
    func requestAccess() async throws -> Bool { false }
    func changes(since token: Data?) async throws -> FinanceChanges { FinanceChanges() }
}

#if DEBUG
/// DEBUG only (APP_SAMPLE_FINANCE=1): plausible Apple Card activity so the sync
/// path can be exercised in the simulator, which has no Wallet data.
struct SampleFinanceSource: FinanceSource {
    var unavailableReason: String? { nil }
    func requestAccess() async throws -> Bool { true }
    func changes(since token: Data?) async throws -> FinanceChanges {
        // Shaped like a real Wallet: two accounts, one without a credit limit, and a
        // pending purchase with no posted date (the mix that broke the first real sync).
        let rows: [(String, String, Int, String, String, Bool, String)] = [
            ("sample-1", "2026-11-20", -2450, "Little Man Ice Cream", "Restaurants", true, "sample-card"),
            ("sample-2", "2026-11-20", -6800, "Denver Botanic Gardens", "Entertainment", true, "sample-card"),
            ("sample-3", "2026-11-19", 25000, "Payment", "Payment", true, "sample-card"),
            ("sample-4", "2026-11-21", -1200, "Sent to a friend", "", false, "sample-cash"),
            // The same purchase reported again once it posts (inserted, then updated).
            ("sample-4", "2026-11-21", -1200, "Sent to a friend", "", true, "sample-cash"),
        ]
        return FinanceChanges(
            accounts: [FinanceAccount(sourceID: "sample-card", kind: "liability", displayName: "Apple Card (sample)",
                                      institution: "Apple", currency: "USD", creditLimitMinor: 1_000_000),
                       FinanceAccount(sourceID: "sample-cash", kind: "asset", displayName: "Apple Cash (sample)",
                                      institution: "Apple", currency: "USD", creditLimitMinor: nil)],
            inserted: rows.map { ImportRow(sourceID: $0.0, txnDate: $0.1, postedDate: $0.5 ? $0.1 : nil, amountMinor: $0.2, currency: "USD",
                                           description: $0.3, merchant: $0.3, category: $0.4,
                                           txnType: $0.2 < 0 ? "pointOfSale" : "billPayment", status: $0.5 ? "booked" : "pending",
                                           mcc: $0.5 ? 5812 : nil, accountSourceID: $0.6) },
            newToken: Data("sample".utf8))
    }
}
#endif

#if canImport(FinanceKit) && os(iOS)
/// The real source (entitlement granted 2026-11-22). isDataAvailable is the
/// only FinanceKit call made before checking it: the others terminate the app
/// where Wallet data doesn't exist (iPad, the simulator).
struct FinanceKitSource: FinanceSource {
    var unavailableReason: String? {
        FinanceStore.isDataAvailable(.financialData) ? nil
            : "Apple Wallet's financial data isn't on this device. Import an Apple Card export instead."
    }

    /// True when the person turned CentMemo's Wallet access off (Settings,
    /// Privacy & Security, Financial Data). The entitlement request promised the
    /// synced data is then deleted (FinanceRevocation).
    static func accessRevoked() async -> Bool {
        guard FinanceStore.isDataAvailable(.financialData) else { return false }
        return (try? await FinanceStore.shared.authorizationStatus()) == .denied
    }

    func requestAccess() async throws -> Bool {
        try await FinanceStore.shared.requestAuthorization() == .authorized
    }

    func changes(since token: Data?) async throws -> FinanceChanges {
        let store = FinanceStore.shared
        var out = FinanceChanges()
        let accounts = try await store.accounts(query: AccountQuery())
        // One history per account; the saved token is a map of account id -> token.
        var tokens = token.flatMap { try? JSONDecoder().decode([String: FinanceStore.HistoryToken].self, from: $0) } ?? [:]
        for account in accounts {
            out.accounts.append(Self.account(account))
            let key = account.id.uuidString
            do {
                try await Self.collect(store, account.id, since: tokens[key], into: &out, token: &tokens[key])
            } catch let error as FinanceError where Self.isInvalidToken(error) {
                // The history was compacted past the saved token: start this account over
                // (upserts on source_id make the replay harmless).
                try await Self.collect(store, account.id, since: nil, into: &out, token: &tokens[key])
            }
        }
        out.newToken = try? JSONEncoder().encode(tokens)
        return out
    }

    private static func collect(_ store: FinanceStore, _ id: UUID, since: FinanceStore.HistoryToken?,
                                into out: inout FinanceChanges, token: inout FinanceStore.HistoryToken?) async throws {
        for try await changes in store.transactionHistory(forAccountID: id, since: since, isMonitoring: false) {
            out.inserted += changes.inserted.map(Self.row)
            out.inserted += changes.updated.map(Self.row)
            out.deletedSourceIDs += changes.deleted.map { (id: UUID) in id.uuidString }
            token = changes.newToken
        }
    }

    private static func isInvalidToken(_ e: FinanceError) -> Bool {
        if case .historyTokenInvalid = e { return true }
        return false
    }

    /// Fits the accounts table's checks (display_name 1-120, institution <= 120,
    /// currency three capitals): one out-of-range value would fail the whole sync.
    private static func name(_ s: String, or fallback: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((t.isEmpty ? fallback : t).prefix(120))
    }
    private static func currency(_ c: String) -> String {
        let u = c.uppercased()
        return u.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil ? u : "USD"
    }

    private static func account(_ a: Account) -> FinanceAccount {
        switch a {
        case .asset(let x):
            FinanceAccount(sourceID: x.id.uuidString, kind: "asset", displayName: name(x.displayName, or: x.institutionName.isEmpty ? "Account" : x.institutionName),
                           institution: String(x.institutionName.prefix(120)), currency: currency(x.currencyCode), creditLimitMinor: nil)
        case .liability(let x):
            FinanceAccount(sourceID: x.id.uuidString, kind: "liability", displayName: name(x.displayName, or: x.institutionName.isEmpty ? "Account" : x.institutionName),
                           institution: String(x.institutionName.prefix(120)), currency: currency(x.currencyCode),
                           creditLimitMinor: x.creditInformation.creditLimit.map { minor($0.amount) })
        @unknown default:
            FinanceAccount(sourceID: UUID().uuidString, kind: "asset", displayName: "Account", institution: "", currency: "USD")
        }
    }

    /// FinanceKit amounts are always positive; the sign is creditDebitIndicator.
    private static func row(_ t: FinanceKit.Transaction) -> ImportRow {
        let amount = minor(t.transactionAmount.amount)
        let iso = { (d: Date) in LedgerDate.string(d) }
        let status: String = switch t.status {
        case .authorized: "authorized"
        case .pending: "pending"
        case .booked: "booked"
        case .memo: "memo"
        case .rejected: "rejected"
        @unknown default: "booked"
        }
        return ImportRow(sourceID: t.id.uuidString, txnDate: iso(t.transactionDate), postedDate: t.postedDate.map(iso),
                         amountMinor: t.creditDebitIndicator == .debit ? -amount : amount,
                         currency: currency(t.transactionAmount.currencyCode),
                         description: String(t.transactionDescription.prefix(500)),
                         merchant: String((t.merchantName ?? "").prefix(200)), category: "",
                         txnType: String(describing: t.transactionType).prefix(40).description, status: status,
                         mcc: t.merchantCategoryCode.map { Int($0.rawValue) },
                         accountSourceID: t.accountID.uuidString)
    }

    private static func minor(_ d: Decimal) -> Int {
        var value = d * 100, rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
#endif

/// Keeps the entitlement request's promise: when the person turns CentMemo's
/// Wallet access off, the Wallet data synced to CentMemo is deleted (their own
/// memos on those purchases go with it; imported exports are untouched).
enum FinanceRevocation {
    @MainActor
    static func check(email: String?) async {
        #if canImport(FinanceKit) && os(iOS)
        let key = FinanceSources.tokenKey(email)
        guard UserDefaults.standard.data(forKey: key) != nil, await FinanceKitSource.accessRevoked() else { return }
        do {
            try await APIClient.shared.deleteFinanceKitData()
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            print("FinanceRevocation: delete failed, will retry next launch: \(error)")
        }
        #endif
    }
}
