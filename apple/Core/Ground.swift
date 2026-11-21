import SwiftUI

/// The person's chosen page color (Decision 059). Values mirror
/// design-tokens.json `grounds`; tools/test_grounds.mjs fails if they drift
/// from the JSON or from the web's css/styles.css.
enum Ground: String, CaseIterable, Identifiable, Sendable {
    case aqua, sky, salmon, apricot, citron, pistachio
    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    /// (light ground, dark ground, dark surface)
    private var hexes: (UInt32, UInt32, UInt32) {
        switch self {
        case .aqua: (0x2FD4EC, 0x131B1C, 0x1C2426)
        case .sky: (0x9AC0F8, 0x161A1F, 0x1F2329)
        case .salmon: (0xFDA19B, 0x1F1717, 0x282120)
        case .apricot: (0xFEA669, 0x1E1814, 0x28211D)
        case .citron: (0xC7C43F, 0x1A1A14, 0x23231D)
        case .pistachio: (0xB4C875, 0x191A14, 0x22241D)
        }
    }

    var color: Color { Self.pair(light: hexes.0, dark: hexes.1) }
    /// Paper on this ground: the token surface in light, a near-neutral of the ground's hue in dark.
    var paper: Color { Self.pair(light: 0xFBFAF7, dark: hexes.2) }
    var swatch: Color { Self.rgb(hexes.0) }

    private static func rgb(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    private static func pair(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb(dark)) : UIColor(rgb(light)) })
        #else
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(rgb(dark)) : NSColor(rgb(light)) })
        #endif
    }
}

/// Editorial type on Apple platforms: New York (the system serif) for titles
/// and the person's memos, matching Newsreader on the web; SF for controls.
enum DisplayType {
    static let title = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let heading = Font.system(.title2, design: .serif).weight(.bold)
    static let memo = Font.system(.body, design: .serif)
}
