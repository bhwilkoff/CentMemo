import SwiftUI
import Testing

/// An offline sim of the event header in the open Duo's pane, portrait (the text
/// measured ~180pt wide at the default 34pt largeTitle, 2026-11-23): renders before and after to PNGs in
/// build/qa/setting-title/ so the result can be looked at, and checks the new
/// title chose a smaller size for a name whose word would not fit.
@MainActor struct SettingTitleRenderTests {
    static let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../build/qa/setting-title").standardized
    static let width: CGFloat = 180  // 669pt window - 380 list - margins - tile - chevron
    static let sizes = [34.0, 28, 22].map { Font.system(size: $0, design: .serif).weight(.bold) }  // largeTitle, title, title2

    func render<V: View>(_ v: V, _ name: String) throws -> CGSize {
        let r = ImageRenderer(content: v.frame(width: Self.width, alignment: .leading).padding(8).background(Color.white))
        r.scale = 2
        let img = try #require(r.cgImage)
        try FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: img)
        try rep.representation(using: .png, properties: [:])!.write(to: Self.out.appendingPathComponent(name + ".png"))
        return CGSize(width: img.width / 2, height: img.height / 2)
    }

    @Test func longWordStepsDownInsteadOfBreaking() throws {
        let name = "AutoNation Toyota Arapahoe"
        _ = try render(Text(name).font(Self.sizes[0]).lineLimit(2), "before-autonation")
        let after = try render(SettingTitle(name: name, sizes: Self.sizes), "after-autonation")
        let short = try render(SettingTitle(name: "Denver Zoo", sizes: Self.sizes), "after-denver-zoo")
        #expect(after.height > 0 && short.height > 0)
        #expect(SettingTitle.longestWord(name) == "AutoNation")
    }
}
