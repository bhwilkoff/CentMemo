#if os(iOS) || os(macOS)
import SwiftUI

/// A theme's color: the store hues chosen by the theme's name (Money.merchantHue),
/// the same everywhere it shows (the thread's marks, the month strip), until D14's
/// default themes carry their own colors.
enum ThemeHue {
    /// D14: each theme's own color (Themes.assignColors, the web's twin).
    static func color(_ theme: String) -> Color { swatch(Themes.colorKey(theme)) }

    static func swatch(_ key: String) -> Color {
        switch key {
        case "clay": .semanticThemeClay
        case "persimmon": .semanticThemePersimmon
        case "ochre": .semanticThemeOchre
        case "olive": .semanticThemeOlive
        case "moss": .semanticThemeMoss
        case "sage": .semanticThemeSage
        case "teal": .semanticThemeTeal
        case "sky": .semanticThemeSky
        case "slate": .semanticThemeSlate
        case "iris": .semanticThemeIris
        case "plum": .semanticThemePlum
        case "rose": .semanticThemeRose
        default: .semanticThemeStone
        }
    }
}

/// D11: the month by theme. One bar split by money spent under each theme, and a
/// legend that names each part, so color is never the only signal (WCAG 1.4.1).
struct MonthStrip: View {
    let parts: [ThemeStrip.Part]
    private var total: Int { parts.reduce(0) { $0 + $1.spentMinor } }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.theme) { p in
                        Rectangle().fill(ThemeHue.color(p.theme))
                            .frame(width: max(4, (g.size.width - CGFloat(parts.count - 1) * 2) * CGFloat(p.spentMinor) / CGFloat(max(total, 1))))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
            FlowLayout(spacing: Spacing.s3) {
                ForEach(parts, id: \.theme) { p in
                    HStack(spacing: 6) {
                        Capsule().fill(ThemeHue.color(p.theme)).frame(width: 14, height: 4)
                        Text(p.theme).font(TypeRamp.caption).foregroundStyle(Color.brandText)
                        Text(Money.format(p.spentMinor)).font(TypeRamp.caption).monospacedDigit().foregroundStyle(Color.brandTextMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("month-strip")
    }
}
#endif
