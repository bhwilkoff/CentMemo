import Foundation
import CryptoKit

/// The money core, ported from js/money/money.js (Decision 057). Amounts are
/// signed integer minor units: negative left the account. Never Double.
/// apple/Tests/MoneyTests.swift holds the same goldens as tests/money.test.mjs,
/// including the web parser's exact source IDs, so the two stay one algorithm.
enum Money {
    enum ParseError: Error, LocalizedError, Equatable {
        case notAnAmount(String), notADate(String), empty, notAppleCard(String)
        var errorDescription: String? {
            switch self {
            case .notAnAmount(let s): "Not an amount: \(s)"
            case .notADate(let s): "Not a date: \(s)"
            case .empty: "The file is empty."
            case .notAppleCard(let col): "This is not an Apple Card export: no \"\(col)\" column."
            }
        }
    }

    /// "12.34", "-1,234.5", "$7" -> integer cents.
    static func toMinor(_ text: String) throws -> Int {
        let s = text.trimmingCharacters(in: .whitespaces).filter { !"$, ".contains($0) }
        let pattern = /^([-+])?(\d+)(?:\.(\d{0,2}))?$/
        guard let m = s.wholeMatch(of: pattern), let whole = Int(m.2) else { throw ParseError.notAnAmount(text) }
        let fraction = String(m.3 ?? "").padding(toLength: 2, withPad: "0", startingAt: 0)
        let minor = whole * 100 + (Int(fraction) ?? 0)
        return m.1 == "-" ? -minor : minor
    }

    static func format(_ minor: Int, currency: String = "USD") -> String {
        let sign = minor < 0 ? "-" : ""
        let abs = Swift.abs(minor)
        let whole = (abs / 100).formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
        let cents = String(format: "%02d", abs % 100)
        let symbol = currency == "USD" ? "$" : currency + " "
        return "\(sign)\(symbol)\(whole).\(cents)"
    }

    /// RFC 4180 CSV: quoted fields, doubled quotes, CRLF or LF.
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false
        var chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 2; continue }
                if c == "\"" { quoted = false; i += 1; continue }
                field.append(c); i += 1; continue
            }
            switch c {
            case "\"": quoted = true
            case ",": row.append(field); field = ""
            case "\r": break
            case "\n": row.append(field); rows.append(row); row = []; field = ""
            default: field.append(c)
            }
            i += 1
        }
        return rows.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// MM/DD/YYYY -> YYYY-MM-DD
    static func isoDate(_ text: String) throws -> String {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "/")
        guard parts.count == 3, let mo = Int(parts[0]), let d = Int(parts[1]), parts[2].count == 4 else {
            throw ParseError.notADate(text)
        }
        return String(format: "%@-%02d-%02d", String(parts[2]), mo, d)
    }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static let appleCardColumns = ["Transaction Date", "Clearing Date", "Description", "Merchant",
                                   "Category", "Type", "Amount (USD)"]

    /// Apple Card CSV export -> rows ready to upsert. Purchases are positive in
    /// the export; CentMemo flips them so spending is negative.
    static func parseAppleCardCSV(_ text: String) throws -> [ImportRow] {
        let rows = parseCSV(text)
        guard let header = rows.first?.map({ $0.trimmingCharacters(in: .whitespaces) }) else { throw ParseError.empty }
        var col: [String: Int] = [:]
        for name in appleCardColumns {
            guard let idx = header.firstIndex(of: name) else { throw ParseError.notAppleCard(name) }
            col[name] = idx
        }
        var seen: [String: Int] = [:]
        var out: [ImportRow] = []
        for f in rows.dropFirst() {
            func get(_ name: String) -> String {
                let i = col[name]!
                return i < f.count ? f[i].trimmingCharacters(in: .whitespaces) : ""
            }
            let clearing = get("Clearing Date")
            let exportAmount = try toMinor(get("Amount (USD)"))
            var row = ImportRow(
                sourceID: "",
                txnDate: try isoDate(get("Transaction Date")),
                postedDate: clearing.isEmpty ? nil : try isoDate(clearing),
                amountMinor: -exportAmount,
                currency: "USD",
                description: String(get("Description").prefix(500)),
                merchant: String(get("Merchant").prefix(200)),
                category: String(get("Category").prefix(80)),
                txnType: String(get("Type").prefix(40)),
                status: clearing.isEmpty ? "pending" : "booked",
                mcc: nil)
            let key = [row.txnDate, String(exportAmount), row.description, row.merchant, row.txnType].joined(separator: "|")
            let n = seen[key, default: 0]
            seen[key] = n + 1
            row.sourceID = "applecard:" + sha256Hex(key).prefix(32) + ":\(n)"
            out.append(row)
        }
        return out
    }
}

/// One transaction on its way into the ledger, from a CSV export or FinanceKit.
struct ImportRow: Codable, Equatable, Sendable {
    var sourceID: String
    var txnDate: String
    var postedDate: String?
    var amountMinor: Int
    var currency: String
    var description: String
    var merchant: String
    var category: String
    var txnType: String
    var status: String
    var mcc: Int?
    /// FinanceKit only: which account the row belongs to (not sent as a column).
    var accountSourceID: String? = nil

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id", txnDate = "txn_date", postedDate = "posted_date", amountMinor = "amount_minor"
        case currency, description, merchant, category, txnType = "txn_type", status, mcc
    }

    /// Every key on every row, nil as null: PostgREST refuses a bulk insert whose
    /// objects differ ("All object keys must match"; Ben's first FinanceKit sync,
    /// 2026-11-22). The synthesized encoder would drop nil optionals.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceID, forKey: .sourceID); try c.encode(txnDate, forKey: .txnDate)
        try c.encode(postedDate, forKey: .postedDate); try c.encode(amountMinor, forKey: .amountMinor)
        try c.encode(currency, forKey: .currency); try c.encode(description, forKey: .description)
        try c.encode(merchant, forKey: .merchant); try c.encode(category, forKey: .category)
        try c.encode(txnType, forKey: .txnType); try c.encode(status, forKey: .status); try c.encode(mcc, forKey: .mcc)
    }
}

/// A FinanceKit account as CentMemo stores it, with every key on every row
/// (an Apple Cash account has no credit limit; see ImportRow.encode).
struct FinanceAccountRow: Encodable, Sendable {
    var sourceID: String, kind: String, displayName: String, institution: String, currency: String
    var creditLimitMinor: Int?
    enum CodingKeys: String, CodingKey {
        case source, sourceID = "source_id", kind, displayName = "display_name", institution, currency, creditLimitMinor = "credit_limit_minor"
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("financekit", forKey: .source); try c.encode(sourceID, forKey: .sourceID); try c.encode(kind, forKey: .kind)
        try c.encode(displayName, forKey: .displayName); try c.encode(institution, forKey: .institution)
        try c.encode(currency, forKey: .currency); try c.encode(creditLimitMinor, forKey: .creditLimitMinor)
    }
}
