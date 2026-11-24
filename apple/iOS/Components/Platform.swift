#if os(iOS) || os(macOS)
import SwiftUI

/// The places where the phone and the Mac differ, named once (apple.md: shared
/// views, native idioms). Everything else in these folders compiles on both.
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// The haptic taxonomy (AGENTS.md), mapped here only. A Mac has no haptics for these.
@MainActor enum Haptic {
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func success() { notify(true) }
    static func error() { notify(false) }
    private static func notify(_ good: Bool) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(good ? .success : .error)
        #endif
    }
}

enum Clipboard {
    static func copy(_ s: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #else
        UIPasteboard.general.string = s
        #endif
    }
}

extension Image {
    init(platform image: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: image)
        #else
        self.init(uiImage: image)
        #endif
    }
}

extension ImageRenderer {
    /// The rendered card, or nil when nothing was drawn.
    @MainActor var platformImage: Image? {
        #if os(macOS)
        nsImage.map { Image(nsImage: $0) }
        #else
        uiImage.map { Image(uiImage: $0) }
        #endif
    }
}

enum Pixels {
    /// Re-drawn and encoded fresh, so no location or camera metadata goes along.
    static func jpeg(_ image: PlatformImage) -> Data? {
        #if os(macOS)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #else
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.jpegData(compressionQuality: 0.8)
        #endif
    }
}

extension ToolbarItemPlacement {
    /// The bar's leading action: the top trailing corner on the phone, the Mac toolbar's own place.
    static var mainAction: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

extension View {
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    func capitalizesWords() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
    /// A Mac sheet takes its size from its content; a Form has none.
    func sheetSize() -> some View {
        #if os(macOS)
        frame(width: 480, height: 620)
        #else
        self
        #endif
    }
    /// The share studio: a page-sized sheet where there is room for the card beside its choices.
    @ViewBuilder func studioSize() -> some View {
        #if os(macOS)
        frame(width: 960, height: 660)
        #else
        presentationSizing(.page)
        #endif
    }
    /// Forms on the Mac are grouped cards, as on the phone (the default there is a bare column).
    func cardForm() -> some View {
        #if os(macOS)
        formStyle(.grouped)
        #else
        self
        #endif
    }
}
#endif
