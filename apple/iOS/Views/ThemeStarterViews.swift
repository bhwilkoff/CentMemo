#if os(iOS) || os(macOS)
import SwiftUI

/// D14: Ben's approved starter themes (Themes.starters), as the web's
/// starterRows, in Settings only (Ben, 2026-11-24). A mark, a name, and what it means.
struct StarterThemeLabel: View {
    let starter: Themes.Starter
    let color: String

    var body: some View {
        HStack(spacing: Spacing.s3) {
            Capsule().fill(ThemeHue.swatch(color)).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(starter.name).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                Text(starter.meaning).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            }
        }
    }
}
#endif
