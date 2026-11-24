import SwiftUI
import Testing

/// DESIGN S: every look, paper and shape draws, and changing a choice changes the
/// card. PNGs land in build/qa/share-card/ to be read beside the web's.
@MainActor struct ShareCardTests {
    static let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../build/qa/share-card").standardized
    static let zoo = ShareContent(memo: "First cold Sunday of the year. The kids raced to the penguins and we stayed until closing.",
                                  setting: "Denver Zoo", initials: "DZ", date: "Nov 16, 2026",
                                  themes: [.init(name: "People I love", paper: 0x9D3A67, night: 0xFF99C2), .init(name: "Adventure", paper: 0x006D91, night: 0x60CCFC)])
    static let long = ShareContent(memo: String(repeating: "We talked about nothing for twenty minutes on the chair, which is the whole reason. ", count: 14),
                                   setting: "Snowbird", initials: "S", date: "Nov 8, 2026")

    func png(_ c: ShareContent, _ d: ShareDesign, _ name: String) throws -> Data {
        let r = ImageRenderer(content: ShareCard(content: c, design: d))
        r.scale = 1
        let img = try #require(r.cgImage)
        #expect(CGSize(width: img.width, height: img.height) == d.shape.size)
        let data = try #require(NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        try data.write(to: Self.out.appendingPathComponent(name + ".png"))
        return data
    }

    @Test func everyLookPaperAndShapeDraws() throws {
        var seen = Set<Data>()
        for look in ShareDesign.Look.allCases {
            for paper in ShareDesign.Paper.allCases {
                for shape in ShareDesign.Shape.allCases {
                    let d = ShareDesign(look: look, paper: paper, shape: shape, mark: 13...16)
                    #expect(seen.insert(try png(Self.zoo, d, "\(look.rawValue)-\(paper.rawValue)-\(shape.rawValue)")).inserted)
                }
            }
        }
    }

    @Test func whatIsHiddenLeavesTheCard() throws {
        let all = try png(Self.zoo, ShareDesign(), "page-all")
        #expect(try png(Self.zoo, ShareDesign(showSetting: false), "page-no-setting") != all)
        #expect(try png(Self.zoo, ShareDesign(showDate: false), "page-no-date") != all)
        #expect(try png(Self.zoo, ShareDesign(showThemes: false), "page-no-themes") != all)
        #expect(try png(Self.zoo, ShareDesign(mark: 0...1), "page-marked") != all)
    }

    @Test func aLongMemoAndNoThemeStillDraw() throws {
        for look in ShareDesign.Look.allCases { _ = try png(Self.long, ShareDesign(look: look, shape: .wide, mark: 4...500), "long-\(look.rawValue)") }
    }

    @Test func underliningTakesTwoTaps() {
        var d = ShareDesign()
        d.tap(5); #expect(d.mark == 5...5)
        d.tap(2); #expect(d.mark == 2...5)
        d.tap(9); #expect(d.mark == 9...9)
    }
}
