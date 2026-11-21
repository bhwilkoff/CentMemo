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
