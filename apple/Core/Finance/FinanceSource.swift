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
        #if canImport(FinanceKit) && os(iOS)
        if FinanceKitSource.isEntitled { return FinanceKitSource() }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.environment["APP_SAMPLE_FINANCE"] == "1" { return SampleFinanceSource() }
        #endif
        return UnavailableFinanceSource()
    }
}

struct UnavailableFinanceSource: FinanceSource {
    var unavailableReason: String? {
        "Waiting on Apple's approval to read Apple Wallet. Until then, import an Apple Card export."
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
        let rows: [(String, String, Int, String, String)] = [
            ("sample-1", "2026-11-20", -2450, "Little Man Ice Cream", "Restaurants"),
            ("sample-2", "2026-11-20", -6800, "Denver Botanic Gardens", "Entertainment"),
            ("sample-3", "2026-11-19", 25000, "Payment", "Payment"),
        ]
        return FinanceChanges(
            accounts: [FinanceAccount(sourceID: "sample-card", kind: "liability", displayName: "Apple Card (sample)",
                                      institution: "Apple", currency: "USD", creditLimitMinor: 1_000_000)],
            inserted: rows.map { ImportRow(sourceID: $0.0, txnDate: $0.1, postedDate: $0.1, amountMinor: $0.2, currency: "USD",
                                           description: $0.3, merchant: $0.3, category: $0.4,
                                           txnType: $0.2 < 0 ? "pointOfSale" : "billPayment", status: "booked", mcc: nil,
                                           accountSourceID: "sample-card") },
            newToken: Data("sample".utf8))
    }
}
#endif

#if canImport(FinanceKit) && os(iOS)
/// The real source, compiled now and switched on when Apple's grant arrives.
struct FinanceKitSource: FinanceSource {
    /// The entitlement is added to CentMemo.entitlements only after Apple
    /// approves it; until then this stays false and FinanceKit is never called.
    static var isEntitled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "CMFinanceKitEnabled") as? Bool == true
            && FinanceStore.isDataAvailable(.financialData)
    }

    var unavailableReason: String? {
        FinanceStore.isDataAvailable(.financialData) ? nil : "Apple Wallet's financial data isn't available on this device."
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
            for try await changes in store.transactionHistory(forAccountID: account.id, since: tokens[key], isMonitoring: false) {
                out.inserted += changes.inserted.map(Self.row)
                out.inserted += changes.updated.map(Self.row)
                out.deletedSourceIDs += changes.deleted.map { (id: UUID) in id.uuidString }
                tokens[key] = changes.newToken
            }
        }
        out.newToken = try? JSONEncoder().encode(tokens)
        return out
    }

    private static func account(_ a: Account) -> FinanceAccount {
        switch a {
        case .asset(let x):
            FinanceAccount(sourceID: x.id.uuidString, kind: "asset", displayName: x.displayName,
                           institution: x.institutionName, currency: x.currencyCode, creditLimitMinor: nil)
        case .liability(let x):
            FinanceAccount(sourceID: x.id.uuidString, kind: "liability", displayName: x.displayName,
                           institution: x.institutionName, currency: x.currencyCode,
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
                         currency: t.transactionAmount.currencyCode,
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
