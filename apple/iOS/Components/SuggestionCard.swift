#if os(iOS)
import SwiftUI

/// One invitation to write (D7). Ben, 2026-11-23: the cards "look almost identical
/// to the regular rows"; "we need to create a proper card that is actually
/// encouraging you to write a memo that is relevant." So the question leads, in
/// the memo's own type, over a pencil line; the place is the small print; and the
/// card ends on the act itself. For "a year ago" the person's words lead instead.
struct SuggestionCard: View {
    let suggestion: APIClient.Suggestion
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(SuggestionWords.reason(suggestion.kind)).font(TypeRamp.caption).foregroundStyle(Color.brandPrimary)
            if let quote = suggestion.memoBody {
                Text("\u{201C}\(quote)\u{201D}").font(DisplayType.memo).foregroundStyle(Color.brandText).lineLimit(4)
            } else if let prompt = SuggestionWords.prompt(suggestion.kind, moment: suggestion.moment) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(prompt).font(.system(.title2, design: .serif).weight(.bold)).foregroundStyle(Color.brandText)
                        .fixedSize(horizontal: false, vertical: true)
                    PencilStroke().stroke(Color.brandPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(height: 8).frame(maxWidth: 220)
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: Spacing.s2) {
                StoreTile(name: entry.displayMerchant, category: entry.category, size: 28)
                Text([entry.displayMerchant, LedgerDate.display(entry.txnDate)].joined(separator: " · "))
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted).lineLimit(2)
                Spacer(minLength: Spacing.s2)
                MoneyText(minor: entry.amountMinor, currency: entry.currency, font: TypeRamp.caption)
                    .foregroundStyle(Color.brandTextMuted)
            }
            Label(suggestion.memoBody == nil ? "Write a memo" : "Read it again", systemImage: suggestion.memoBody == nil ? "pencil" : "book")
                .font(TypeRamp.bodyStrong).foregroundStyle(Color.brandPrimary)
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.brandPrimary.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("suggestion-\(suggestion.kind)")
    }
}
#endif
