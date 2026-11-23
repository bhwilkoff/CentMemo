import Foundation

/// Rows as the CentMemo database returns them (same shapes the web app reads).
struct LedgerEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let accountID: String
    let txnDate: String
    let postedDate: String?
    let amountMinor: Int
    let currency: String
    let description: String
    let merchant: String
    let category: String
    let txnType: String
    let status: String
    /// Set when the person skipped this event as a detail (Decision 065).
    let skippedAt: String?
    var memo: Memo?
    var accountName: String?
    /// D8 renames: the person's name for this Setting, filled in by APIClient.
    var placeName: String?

    /// The Setting's key: the bank's text cleaned (one algorithm with the web).
    var settingKey: String {
        let name = Money.cleanMerchant(merchant.isEmpty ? description : merchant)
        return name.isEmpty ? "Unknown" : name
    }
    var displayMerchant: String { placeName ?? settingKey }
    var isCredit: Bool { amountMinor > 0 }
    var isSkipped: Bool { skippedAt != nil }
    /// Cash back and interest landing in Apple Cash or Savings (FinanceKit types
    /// "deposit" and "interest"): details, hidden from the Narrative by default
    /// (Ben, 2026-11-22); the filters will show them on request.
    var isQuietDetail: Bool { txnType == "deposit" || txnType == "interest" }

    struct Memo: Decodable, Hashable, Sendable {
        let body: String
        let valueIDs: [String]
        let valueNames: [String]

        private enum Keys: String, CodingKey { case body, memoValues = "memo_values" }
        private struct MemoValue: Decodable {
            let valueID: String?
            let lifeValues: Named?
            struct Named: Decodable { let name: String }
            enum CodingKeys: String, CodingKey { case valueID = "value_id", lifeValues = "life_values" }
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            body = try c.decode(String.self, forKey: .body)
            let values = try c.decodeIfPresent([MemoValue].self, forKey: .memoValues) ?? []
            valueIDs = values.compactMap(\.valueID)
            valueNames = values.compactMap { $0.lifeValues?.name }
        }
    }

    private enum Keys: String, CodingKey {
        case id, accountID = "account_id", txnDate = "txn_date", postedDate = "posted_date"
        case amountMinor = "amount_minor", currency, description, merchant, category, plainCategory = "plain_category"
        case txnType = "txn_type", status, memos, accounts, skippedAt = "skipped_at"
    }
    private struct AccountName: Decodable { let display_name: String }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        accountID = try c.decodeIfPresent(String.self, forKey: .accountID) ?? ""
        txnDate = try c.decode(String.self, forKey: .txnDate)
        postedDate = try c.decodeIfPresent(String.self, forKey: .postedDate)
        amountMinor = try c.decode(Int.self, forKey: .amountMinor)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        // D8: Apple Card's category words for every event, read from the merchant
        // category code when the bank gave none (plain_category, in the database).
        let plain = try c.decodeIfPresent(String.self, forKey: .plainCategory) ?? ""
        category = plain.isEmpty ? (try c.decodeIfPresent(String.self, forKey: .category) ?? "") : plain
        txnType = try c.decodeIfPresent(String.self, forKey: .txnType) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "booked"
        skippedAt = try c.decodeIfPresent(String.self, forKey: .skippedAt)
        // One memo per transaction: PostgREST sends an object, or an array from a view.
        if let one = try? c.decodeIfPresent(Memo.self, forKey: .memos) { memo = one }
        else if let many = try? c.decodeIfPresent([Memo].self, forKey: .memos) { memo = many.first }
        else { memo = nil }
        accountName = (try? c.decodeIfPresent(AccountName.self, forKey: .accounts))??.display_name
    }
}

struct LifeValue: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    /// D14: the color the person chose; nil lets Themes.assignColors pick.
    var color: String? = nil
    var createdAt: String? = nil

    enum CodingKeys: String, CodingKey { case id, name, color, createdAt = "created_at" }
}

/// "2026-11-18" helpers shared by every view.
enum LedgerDate {
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func date(_ s: String) -> Date? { iso.date(from: s) }
    static func string(_ d: Date) -> String { iso.string(from: d) }
    static func display(_ s: String) -> String {
        guard let d = date(s) else { return s }
        // Ledger dates are calendar days, parsed at UTC midnight: format at UTC
        // too, or every date west of Greenwich shows a day early.
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US"))
        style.timeZone = TimeZone(identifier: "UTC")!
        return d.formatted(style)
    }
    /// "2026-11" -> "November 2026"
    static func monthName(_ ym: String) -> String {
        guard let d = date(ym + "-01") else { return ym }
        var style = Date.FormatStyle.dateTime.month(.wide).year()
        style.timeZone = TimeZone(identifier: "UTC")!
        return d.formatted(style)
    }
    static func step(_ ym: String, by months: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let d = date(ym + "-01"), let n = cal.date(byAdding: .month, value: months, to: d) else { return ym }
        return String(string(n).prefix(7))
    }
    static func lastDay(_ ym: String) -> String {
        let next = step(ym, by: 1)
        guard let d = date(next + "-01") else { return ym + "-28" }
        return string(d.addingTimeInterval(-86_400))
    }
    static var thisMonth: String { String(string(Date()).prefix(7)) }
}

/// D8: a push to one Setting's page (every visit there), by its cleaned name.
struct SettingRoute: Hashable, Sendable { let name: String }
