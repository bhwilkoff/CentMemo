import Foundation
import Testing

/// W7: a picture whose words are money never goes into a share.
struct MoneyWordsTests {
    @Test func moneyIsFound() {
        for s in ["$12", "Total 18.40", "€ 7", "12 €", "SUBTOTAL", "Tip", "USD 40", "Amount due", "4,99"] {
            #expect(MoneyWords.found(in: s), "\(s)")
        }
    }
    @Test func ordinaryWordsAreNot() {
        for s in ["Denver Zoo", "Penguins!", "Open 9 to 5", "Nov 16, 2026", "Table 12", "Totally worth it", "Room 101", ""] {
            #expect(!MoneyWords.found(in: s), "\(s)")
        }
    }
}
