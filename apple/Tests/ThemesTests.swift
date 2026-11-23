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
}
