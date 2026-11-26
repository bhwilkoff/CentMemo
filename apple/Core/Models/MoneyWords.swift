import Foundation

/// W7: words in a picture that are money: a currency sign or code by a number, a price
/// with cents, or a receipt's own words. A picture that reads as money never goes into a
/// share (Ben, 2026-11-24: "No amount of money should ever be shared").
nonisolated enum MoneyWords {
    static func found(in text: String) -> Bool {
        let patterns = [#"[$€£¥]\s?\d"#, #"\d\s?[$€£¥]"#, #"\b\d{1,6}[.,]\d{2}\b"#,
                        #"\b(USD|EUR|GBP|subtotal|total|tax|tip|amount|balance|paid)\b"#]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}
