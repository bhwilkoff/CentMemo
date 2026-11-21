import SwiftUI

/// The person's color (Decision 060, docs/DESIGN.md C3-C5): a mark, never a
/// ground. It shows what still needs a memo and the values they name; the
/// same bright value in light and dark, with ink text on it. Values mirror
/// design-tokens.json `grounds`; tools/test_grounds.mjs fails on drift.
enum Ground: String, CaseIterable, Identifiable, Sendable {
    case aqua, sky, salmon, apricot, citron, pistachio
    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    private var hex: UInt32 {
        switch self {
        case .aqua: 0x2FD4EC
        case .sky: 0x9AC0F8
        case .salmon: 0xFDA19B
        case .apricot: 0xFEA669
        case .citron: 0xC7C43F
        case .pistachio: 0xB4C875
        }
    }

    var color: Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    /// Text on the person's color is ink in both modes (C5).
    static let onColor = Color(.sRGB, red: 0x23 / 255, green: 0x1B / 255, blue: 0x1C / 255)
}

/// Editorial type on Apple platforms: New York (the system serif) for titles
/// and the person's memos, matching Newsreader on the web; SF for controls.
enum DisplayType {
    static let title = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let memo = Font.system(.body, design: .serif)
}
