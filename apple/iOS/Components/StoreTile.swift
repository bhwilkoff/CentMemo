#if os(iOS)
import SwiftUI

/// A store you recognize at a glance (D8), made on the phone with no logo
/// service: the store's initials in ink on paper, a pencil mark in the store's
/// own hue (Money.merchantHue, the same on the web), and the category's glyph.
/// The glyph carries the category, so meaning never rests on color alone.
struct StoreTile: View {
    let name: String
    var category: String = ""
    var size: CGFloat = 40

    static let hues: [Color] = [.semanticStoreClay, .semanticStoreOchre, .semanticStoreSage,
                                .semanticStoreSlate, .semanticStoreRose, .semanticStoreStone]

    var body: some View {
        let r = size * 0.25
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: r).fill(Color.brandSurface)
            RoundedRectangle(cornerRadius: r).strokeBorder(Color.brandBorder, lineWidth: 1)
            Text(Money.merchantInitials(name))
                .font(.system(size: size * 0.34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.brandText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, size * 0.14).padding(.bottom, size * 0.26)
            Capsule().fill(Self.hues[Money.merchantHue(name, count: Self.hues.count)])
                .frame(height: max(2, size * 0.05)).padding(.horizontal, size * 0.16).padding(.bottom, size * 0.13)
            if let glyph = Self.glyph(category) {
                Image(systemName: glyph).font(.system(size: size * 0.2, weight: .medium))
                    .foregroundStyle(Color.brandTextMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Apple Card's categories, by the SF Symbol that reads as each.
    static func glyph(_ category: String) -> String? {
        switch category.lowercased() {
        case "restaurants": "fork.knife"
        case "grocery": "cart"
        case "gas": "fuelpump"
        case "shopping": "bag"
        case "transportation": "car"
        case "entertainment": "ticket"
        case "travel", "airlines": "airplane"
        case "hotels": "bed.double"
        case "health", "medical": "cross.case"
        case "utilities": "bolt"
        case "services": "wrench.and.screwdriver"
        case "installment": "creditcard"
        case "interest": "percent"
        case "payment", "credit": "arrow.uturn.down"
        default: nil
        }
    }
}
#endif
