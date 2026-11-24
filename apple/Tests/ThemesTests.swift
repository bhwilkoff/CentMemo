import Foundation
import Testing

/// D14: the same golden as tests/themes.test.mjs, and the starter list held to
/// the approved data file.
@MainActor
struct ThemesTests {
    @Test func startersMatchTheApprovedData() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../tests/fixtures/starter-themes.json").standardized
        struct File: Decodable { let palette: [String]; let starters: [S] }
        struct S: Decodable { let name, meaning, color: String }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        #expect(Themes.palette == file.palette)
        #expect(Themes.starters == file.starters.map { .init(name: $0.name, meaning: $0.meaning, color: $0.color) })
    }

    @Test func hexIsTheTokens() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../design-tokens.json").standardized
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let sem = try #require((root["color"] as? [String: Any])?["semantic"] as? [String: [String: String]])
        for key in Themes.palette {
            let t = try #require(sem["theme" + key.prefix(1).uppercased() + key.dropFirst()])
            #expect(Themes.hex[key]?.paper == UInt32(t["light"]!.dropFirst(), radix: 16))
            #expect(Themes.hex[key]?.night == UInt32(t["dark"]!.dropFirst(), radix: 16))
        }
    }

    @Test func golden() {
        let input: [Themes.Input] = [
            .init(name: "Time with my kids", createdAt: "2026-11-21T10:00:00Z"),
            .init(name: "Great meals", createdAt: "2026-11-21T10:01:00Z"),
            .init(name: "Being outside", createdAt: "2026-11-21T10:02:00Z"),
            .init(name: "Clay pot", color: "clay", createdAt: "2026-11-22T09:00:00Z"),
            .init(name: "Home", createdAt: "2026-11-22T09:01:00Z"),
        ]
        #expect(Themes.assignColors(input) == ["clay pot": "clay", "great meals": "persimmon", "time with my kids": "ochre",
                                               "being outside": "olive", "home": "moss"])
    }

    @Test func nextColor() {
        let input: [Themes.Input] = [
            .init(name: "Time with my kids", createdAt: "2026-11-21T10:00:00Z"),
            .init(name: "Great meals", createdAt: "2026-11-21T10:01:00Z"),
            .init(name: "Being outside", createdAt: "2026-11-21T10:02:00Z"),
            .init(name: "Clay pot", color: "clay", createdAt: "2026-11-22T09:00:00Z"),
            .init(name: "Home", createdAt: "2026-11-22T09:01:00Z"),
        ]
        #expect(Themes.nextColor(Array(input.prefix(4)), name: "Home") == "moss")
        #expect(Themes.nextColor(Array(input.prefix(3)), name: "Home") == "olive")
    }
}
