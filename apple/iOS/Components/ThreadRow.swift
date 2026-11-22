#if os(iOS)
import SwiftUI

/// The Narrative as a thread (D10, the Chronicle direction): a pencil line runs
/// down the month. A written memo is a filled mark in its first theme's hue,
/// with the memo as the headline; an event still waiting is a small hollow
/// mark and one quiet line. The money stays a footnote (Decision 065).
struct ThreadRow: View {
    let entry: LedgerEntry

    private var written: Bool { entry.memo != nil }
    /// A theme wears a store hue chosen the same way as a Setting's (Money.merchantHue),
    /// until D14's default themes carry their own colors.
    private var hue: Color {
        guard let theme = entry.memo?.valueNames.first else { return Color.brandPrimary }
        return StoreTile.hues[Money.merchantHue(theme, count: StoreTile.hues.count)]
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            ZStack(alignment: .top) {
                Rectangle().fill(Color.brandBorder).frame(width: 2).frame(maxHeight: .infinity)
                Circle()
                    .fill(written ? hue : Color.brandBackground)
                    .overlay(Circle().strokeBorder(written ? hue : Color.brandBorder, lineWidth: 2))
                    .frame(width: written ? 14 : 10, height: written ? 14 : 10)
                    .padding(.top, written ? 6 : 7)
            }
            .frame(width: 16)
            .accessibilityHidden(true)
            if let memo = entry.memo {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(memo.body).font(DisplayType.memo).foregroundStyle(Color.brandText).lineLimit(4)
                    HStack(spacing: Spacing.s2) {
                        StoreTile(name: entry.displayMerchant, category: entry.category, size: 24)
                        Text("\(LedgerDate.display(entry.txnDate)) · \(entry.displayMerchant)")
                            .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        if let theme = memo.valueNames.first {
                            Text(theme).font(TypeRamp.caption).foregroundStyle(hue)
                        }
                    }
                }
                .padding(.vertical, Spacing.s2)
            } else {
                HStack(spacing: Spacing.s2) {
                    Text("\(LedgerDate.display(entry.txnDate)) · \(entry.displayMerchant)")
                        .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    Spacer(minLength: Spacing.s2)
                    MoneyText(minor: entry.amountMinor, currency: entry.currency, font: TypeRamp.caption)
                        .opacity(0.8)
                }
                .padding(.vertical, Spacing.s1 + 2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
