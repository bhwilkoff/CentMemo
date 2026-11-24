import Foundation
import Testing

/// DESIGN S7, Decision 067: what the app sends to make a link, and what it never does.
struct StoryLinkTests {
    static func draft() -> StoryLinkDraft {
        .init(kind: .memo, theme: .init(id: "v1", name: "Great meals", color: "persimmon"), items: [
            .init(id: "t1", memo: "First cold Sunday. We stayed until closing.", shown: "Denver Zoo", shownWhen: "Nov 16, 2026", mark: 3...6)])
    }
    static func json(_ v: some Encodable) throws -> String { String(decoding: try JSONEncoder().encode(v), as: UTF8.self) }

    @Test func theStoreAndDateAreNeverFilledInForWallet() throws {
        var d = Self.draft()
        #expect(!(try Self.json(d.request)).contains("Denver Zoo"), "nothing is filled in before the source is known")
        d.fill(wallet: ["t1"])
        #expect(!(try Self.json(d.request)).contains("Denver Zoo"))
        #expect(!(try Self.json(d.preview)).contains("Nov 16"))
        d.fill(wallet: [])
        #expect((try Self.json(d.request)).contains("Denver Zoo"), "an imported purchase may start with its place")
    }

    @Test func theWritersWordsAreKept() {
        var d = Self.draft()
        d.items[0].place = "The zoo"
        d.fill(wallet: [])
        #expect(d.items[0].place == "The zoo")
        #expect(d.items[0].when == "Nov 16, 2026")
    }

    @Test func theRequestIsTheServersShape() throws {
        var d = Self.draft()
        d.sharedBy = "  "; d.paper = .night; d.pencil = .circle
        let o = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(d.request)) as? [String: Any])
        #expect(Set(o.keys) == ["p_kind", "p_items", "p_design", "p_value"], "no name typed, none sent")
        let item = try #require((o["p_items"] as? [[String: Any]])?.first)
        #expect(Set(item.keys) == ["txn", "place", "when", "mark"])
        #expect(item["mark"] as? [Int] == [3, 6])
        let design = try #require(o["p_design"] as? [String: Any])
        #expect(Set(design.keys) == ["color", "paper", "pencil", "lead", "place", "when", "theme", "cover", "lines", "mems"])
        #expect(design["paper"] as? String == "night" && design["pencil"] as? String == "circle")
    }

    @Test func aPageWithNothingOnItIsRefusedInWords() {
        var d = Self.draft()
        #expect(d.problem == nil)
        d.items[0].on = false
        #expect(d.problem != nil)
        var t = Self.draft()
        t.kind = .theme; t.cover = false; t.lines = false; t.mems = false
        #expect(t.problem != nil)
    }

    @Test func theAddressHoldsTheCodeAfterTheHash() {
        #expect(StoryLink.url("abc_-").absoluteString == "https://centmemo.com/s/#abc_-")
    }
}
