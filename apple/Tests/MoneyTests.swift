import Foundation
import Testing

/// The same goldens as tests/money.test.mjs. The source IDs below were printed
/// by the web parser (js/money/money.js) for tests/fixtures/applecard-sample.csv;
/// if either platform's algorithm drifts, this suite fails (cross-platform parity).
@MainActor
struct MoneyTests {
    static let fixture = """
    Transaction Date,Clearing Date,Description,Merchant,Category,Type,Amount (USD),Purchased By
    11/18/2026,11/19/2026,"BLUE PAN PIZZA 3930 W 38TH AVE DENVER 80212 CO USA",Blue Pan Pizza,Restaurants,Purchase,64.37,Sample Person
    11/18/2026,11/19/2026,"BLUE PAN PIZZA 3930 W 38TH AVE DENVER 80212 CO USA",Blue Pan Pizza,Restaurants,Purchase,64.37,Sample Person
    11/16/2026,11/17/2026,"DENVER ZOO 2300 STEELE ST DENVER 80205 CO USA",Denver Zoo,Entertainment,Purchase,"1,082.00",Sample Person
    11/15/2026,11/15/2026,"ACH DEPOSIT INTERNET TRANSFER FROM ACCOUNT ENDING IN 0000",Payment,Payment,Payment,-500.00,Sample Person
    11/14/2026,,"APPLE.COM/BILL ONE APPLE PARK WAY 866-712-7753 95014 CA USA",Apple Services,Other,Purchase,9.99,Sample Person
    11/10/2026,11/11/2026,"MONTHLY INSTALLMENTS (3 OF 12)",Apple,Installment,Installment,41.58,Sample Person
    11/01/2026,11/01/2026,"INTEREST CHARGE",Interest,Interest,Interest,0.07,Sample Person
    """

    static let webSourceIDs = [
        "applecard:8a9be7d1af5e044c6189bb04a46212d5:0",
        "applecard:8a9be7d1af5e044c6189bb04a46212d5:1",
        "applecard:3e5df91a0d20e21e78105ebd0167b662:0",
        "applecard:716f4ab4b98ceef55a3febecd1cd3e76:0",
        "applecard:446aecaf39c3801207e8e6f72ca7b624:0",
        "applecard:432bc38098cd216cd642e44a04d168e2:0",
        "applecard:a7d369b68e430f741cbb7495cf350a07:0",
    ]

    @Test func toMinorParsesWithoutFloats() throws {
        #expect(try Money.toMinor("64.37") == 6437)
        #expect(try Money.toMinor("1,082.00") == 108200)
        #expect(try Money.toMinor("-500.00") == -50000)
        #expect(try Money.toMinor("0.07") == 7)
        #expect(try Money.toMinor("7") == 700)
        #expect(try Money.toMinor("0.1") == 10)
        #expect(throws: Money.ParseError.self) { try Money.toMinor("1.234") }
        #expect(throws: Money.ParseError.self) { try Money.toMinor("abc") }
    }

    @Test func formats() {
        #expect(Money.format(-108200) == "-$1,082.00")
        #expect(Money.format(7) == "$0.07")
    }

    @Test func appleCardExportMatchesWebGoldens() throws {
        let rows = try Money.parseAppleCardCSV(Self.fixture)
        #expect(rows.map(\.amountMinor) == [-6437, -6437, -108200, 50000, -999, -4158, -7])
        #expect(rows.reduce(0) { $0 + $1.amountMinor } == -76238)
        #expect(rows[4].status == "pending")
        #expect(rows[4].postedDate == nil)
        #expect(rows[0].postedDate == "2026-11-19")
        #expect(rows.map(\.sourceID) == Self.webSourceIDs)
    }

    @Test func refusesOtherFiles() {
        #expect(throws: Money.ParseError.notAppleCard("Transaction Date")) {
            try Money.parseAppleCardCSV("Date,Amount\n1/1/2026,5")
        }
    }
}

/// Ledger dates are calendar days; they must display as written in any time zone.
@MainActor
struct LedgerDateTests {
    @Test func displaysTheCalendarDayWritten() {
        #expect(LedgerDate.display("2026-11-17") == "Nov 17, 2026")
        #expect(LedgerDate.monthName("2026-11") == "November 2026")
        #expect(LedgerDate.lastDay("2026-02") == "2026-02-28")
        #expect(LedgerDate.step("2026-01", by: -1) == "2025-12")
    }
}

/// PostgREST refuses a bulk insert whose objects carry different keys ("All
/// object keys must match"). Swift's synthesized Encodable drops nil optionals,
/// so a pending purchase (no posted date) or an account without a credit limit
/// broke Ben's first real FinanceKit sync (2026-11-22). Every row must carry
/// every key, nil as null.
struct UniformKeysTests {
    private func keys<T: Encodable>(_ v: T) throws -> Set<String> {
        let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(v)) as! [String: Any]
        return Set(obj.keys)
    }

    @Test func importRowsCarryEveryKey() throws {
        let posted = ImportRow(sourceID: "a", txnDate: "2026-11-20", postedDate: "2026-11-21", amountMinor: -100, currency: "USD",
                               description: "d", merchant: "m", category: "", txnType: "pointOfSale", status: "booked", mcc: 5411)
        var pending = posted; pending.postedDate = nil; pending.mcc = nil; pending.status = "pending"
        #expect(try keys(posted) == keys(pending))
        #expect(try !keys(posted).contains("accountSourceID"), "the account is a relationship, not a column")
    }

    @Test func accountRowsCarryEveryKey() throws {
        let card = FinanceAccountRow(sourceID: "c", kind: "liability", displayName: "Apple Card", institution: "Apple", currency: "USD", creditLimitMinor: 500_000)
        let cash = FinanceAccountRow(sourceID: "s", kind: "asset", displayName: "Apple Cash", institution: "Apple", currency: "USD", creditLimitMinor: nil)
        #expect(try keys(card) == keys(cash))
    }
}

/// FinanceKit reports one purchase more than once; the upload must carry it once,
/// in its latest state, and never a purchase that ends deleted.
struct FinanceChangesTests {
    private func row(_ id: String, _ status: String, posted: String? = nil) -> ImportRow {
        ImportRow(sourceID: id, txnDate: "2026-11-20", postedDate: posted, amountMinor: -100, currency: "USD",
                  description: "d", merchant: "m", category: "", txnType: "pointOfSale", status: status, mcc: nil)
    }

    @Test func eachPurchaseOnceInItsLatestState() {
        var c = FinanceChanges()
        c.inserted = [row("a", "pending"), row("b", "booked"), row("a", "booked", posted: "2026-11-21")]
        let n = c.normalized()
        #expect(n.inserted.map(\.sourceID).sorted() == ["a", "b"])
        #expect(n.inserted.first { $0.sourceID == "a" }?.status == "booked")
    }

    @Test func aPurchaseThatEndsDeletedIsNotUploaded() {
        var c = FinanceChanges()
        c.inserted = [row("a", "pending"), row("b", "booked")]
        c.deletedSourceIDs = ["a"]
        let n = c.normalized()
        #expect(n.inserted.map(\.sourceID) == ["b"])
        #expect(n.deletedSourceIDs == ["a"])
    }
}

struct ErrorWordsTests {
    @Test func offlineAndUnreachableReadLikeTheWeb() {
        #expect(SessionStore.describe(URLError(.notConnectedToInternet)) == "You're offline.")
        #expect(SessionStore.describe(URLError(.cannotConnectToHost)) == "CentMemo couldn't reach its server.")
        #expect(SessionStore.describe(URLError(.timedOut)) == "CentMemo couldn't reach its server.")
        #expect(SessionStore.describe(APIClient.APIError.server("Nope")) == APIClient.APIError.server("Nope").localizedDescription)
    }
}

/// The web's store-name golden, read from the same file (tests/fixtures/merchant-names.json).
struct MerchantNameTests {
    struct Golden: Decodable { let raw: String, name: String, initials: String, hue: Int }
    @Test func matchesTheWebGolden() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../tests/fixtures/merchant-names.json").standardized
        let golden = try JSONDecoder().decode([Golden].self, from: Data(contentsOf: url))
        #expect(golden.count >= 12)
        for g in golden {
            let name = Money.cleanMerchant(g.raw)
            #expect(name == g.name, "\(g.raw)")
            #expect(Money.merchantInitials(name) == g.initials, "\(g.raw)")
            #expect(Money.merchantHue(name) == g.hue, "\(g.raw)")
        }
    }
}

struct SyntheticAccountTests {
    @Test func recognizesOnlyTheHarnessAndReviewerAccounts() {
        #expect(SessionStore.isSynthetic("test-owner@centmemo.com"))
        #expect(SessionStore.isSynthetic("Review@CentMemo.com"))
        #expect(!SessionStore.isSynthetic("ben@learningischange.com"))
        #expect(!SessionStore.isSynthetic("test-owner@gmail.com"))
        #expect(!SessionStore.isSynthetic(nil))
    }
}

/// The web's goldens for Venmo, PayPal, and Cash App, from the same fixture files.
struct OtherSourcesTests {
    private func fx(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../tests/fixtures/" + name).standardized, encoding: .utf8)
    }
    private func shape(_ r: [ImportRow]) -> [String] { r.map { "\($0.sourceID)|\($0.txnDate)|\($0.amountMinor)|\($0.merchant)|\($0.description)" } }

    @Test func detectsEachSource() throws {
        #expect(Money.detectExport(try fx("applecard-sample.csv")) == .applecard)
        #expect(Money.detectExport(try fx("venmo-sample.csv")) == .venmo)
        #expect(Money.detectExport(try fx("paypal-sample.csv")) == .paypal)
        #expect(Money.detectExport(try fx("cashapp-sample.csv")) == .cashapp)
        #expect(Money.detectExport("Name,Amount\nCoffee,3.00\n") == nil)
    }
    @Test func venmo() throws {
        #expect(shape(try Money.parseVenmoCSV(try fx("venmo-sample.csv"))) == [
            "venmo:3912345678901234567|2026-11-03|-1850|Alex Rivera|Pizza night 🍕, my half",
            "venmo:3912345678901234568|2026-11-05|4000|Jordan Lee|Concert tickets",
            "venmo:3912345678901234569|2026-11-09|-102150||"])
    }
    @Test func payPal() throws {
        #expect(shape(try Money.parsePayPalCSV(try fx("paypal-sample.csv"))) == [
            "paypal:8AB12345CD678901E|2026-11-02|-2399|Riverside Bookshop|Used poetry book",
            "paypal:9XY12345CD678901F|2026-11-02|2399||",
            "paypal:1ZZ12345CD678901G|2026-11-04|-125000|Sam Okafor|November rent, thank you!"])
    }
    @Test func cashApp() throws {
        #expect(shape(try Money.parseCashAppCSV(try fx("cashapp-sample.csv"))) == [
            "cashapp:rmgsrz|2026-11-01|-290|MTA*NYCT PAYGO|",
            "cashapp:7jdb8q|2026-11-03|-1500|Dana Park|Lunch with Dana",
            "cashapp:4pp9tt|2026-11-07|100000|Mom|Birthday gift 🎂"])
    }
    @Test func looseMinorEverySign() throws {
        for (t, v) in [("- $65.00", -6500), ("+ $10.00", 1000), ("-$2.90", -290), ("($2.90)", -290), ("$1", 100), ("-6.99", -699), ("1,234.50", 123450)] {
            #expect(try Money.looseMinor(t) == v, "\(t)")
        }
    }
}

struct NarrativeFilterTests {
    private func entry(_ id: String, type: String = "pointOfSale", memo: String? = nil, themes: [String] = [], skipped: Bool = false) throws -> LedgerEntry {
        var json: [String: Any] = ["id": id, "txn_date": "2026-11-20", "amount_minor": -100, "txn_type": type]
        if skipped { json["skipped_at"] = "2026-11-22T00:00:00Z" }
        if let memo { json["memos"] = ["body": memo, "memo_values": themes.map { ["value_id": $0, "life_values": ["name": $0]] }] }
        return try JSONDecoder().decode(LedgerEntry.self, from: JSONSerialization.data(withJSONObject: json))
    }
    @Test func defaultHidesDetailsAndSkipped() throws {
        let list = [try entry("a"), try entry("b", type: "deposit"), try entry("c", skipped: true), try entry("d", type: "interest")]
        #expect(NarrativeFilter().apply(list).map(\.id) == ["a"])
        #expect(NarrativeFilter(details: true).apply(list).map(\.id) == ["a", "b", "d"])
    }
    @Test func writtenUnwrittenAndTheme() throws {
        let list = [try entry("a"), try entry("b", memo: "Zoo", themes: ["People I love"]), try entry("c", memo: "Pizza", themes: ["Great meals"])]
        #expect(NarrativeFilter(show: .written).apply(list).map(\.id) == ["b", "c"])
        #expect(NarrativeFilter(show: .unwritten).apply(list).map(\.id) == ["a"])
        #expect(NarrativeFilter(theme: "Great meals").apply(list).map(\.id) == ["c"])
    }
}

struct ThemeStripTests {
    private func entry(_ id: String, _ minor: Int, memo: String? = nil, themes: [String] = [], skipped: Bool = false) throws -> LedgerEntry {
        var json: [String: Any] = ["id": id, "txn_date": "2026-11-20", "amount_minor": minor]
        if skipped { json["skipped_at"] = "2026-11-22T00:00:00Z" }
        if let memo { json["memos"] = ["body": memo, "memo_values": themes.map { ["value_id": $0, "life_values": ["name": $0]] }] }
        return try JSONDecoder().decode(LedgerEntry.self, from: JSONSerialization.data(withJSONObject: json))
    }
    @Test func firstThemeOnlyBiggestFirst() throws {
        let list = [try entry("a", -1000, memo: "Zoo", themes: ["People I love", "Adventure"]),
                    try entry("b", -2500, memo: "Pizza", themes: ["Great meals"]),
                    try entry("c", -500, memo: "Book", themes: ["People I love"]),
                    try entry("d", -9999),                       // unwritten: not in the strip
                    try entry("e", 4000, memo: "Refund", themes: ["Great meals"]),  // money in: not spending
                    try entry("f", -700, memo: "x", themes: ["Joy"], skipped: true)]
        #expect(ThemeStrip.parts(list) == [.init(theme: "Great meals", spentMinor: 2500), .init(theme: "People I love", spentMinor: 1500)])
    }
}
