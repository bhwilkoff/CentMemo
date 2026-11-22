#if os(iOS)
import SwiftUI

/// One suggested moment (D7): the reason it was picked, the Setting, and a
/// prompt, or for "a year ago" the person's own words, quoted exactly.
struct SuggestionCard: View {
    let suggestion: APIClient.Suggestion
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(SuggestionWords.reason(suggestion.kind)).font(TypeRamp.caption).foregroundStyle(Color.brandPrimary)
            if let quote = suggestion.memoBody {
                Text("\u{201C}\(quote)\u{201D}").font(DisplayType.memo).foregroundStyle(Color.brandText).lineLimit(4)
                Text("\(LedgerDate.display(entry.txnDate)) · \(entry.displayMerchant)")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            } else {
                HStack(spacing: Spacing.s3) {
                    StoreTile(name: entry.displayMerchant, category: entry.category)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayMerchant).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                        Text(LedgerDate.display(entry.txnDate)).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    }
                }
                if let prompt = SuggestionWords.prompt(suggestion.kind) {
                    Text(prompt).font(DisplayType.memo).italic().foregroundStyle(Color.brandTextMuted)
                }
            }
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("suggestion-\(suggestion.kind)")
    }
}
#endif
