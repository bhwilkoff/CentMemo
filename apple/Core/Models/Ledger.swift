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
    var memo: Memo?
    var accountName: String?

    var displayMerchant: String {
        let name = Money.cleanMerchant(merchant.isEmpty ? description : merchant)
        return name.isEmpty ? "Unknown" : name
    }
    var isCredit: Bool { amountMinor > 0 }

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
        case amountMinor = "amount_minor", currency, description, merchant, category
        case txnType = "txn_type", status, memos, accounts
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
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        txnType = try c.decodeIfPresent(String.self, forKey: .txnType) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "booked"
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
