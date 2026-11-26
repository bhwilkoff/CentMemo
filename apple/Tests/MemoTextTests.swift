import Testing
import Foundation

/// W4: one reader and one writer for a memo's styled text, proved by round trips.
struct MemoTextTests {
    typealias L = MemoText.Line
    typealias R = MemoText.Run

    @Test func plainMemosStayExactlyAsWritten() {
        for s in ["First cold Sunday of the year.", "Two lines\nof words", "", "Ends with a space ", "$12 for 3 apples, 50% off!"] {
            #expect(MemoText.markdown(MemoText.parse(s)) == s)
            #expect(MemoText.plain(s) == s)
        }
    }

    @Test func stylesReadAndWriteBack() {
        let lines = [
            L(block: .heading, runs: [R(text: "Sunday")]),
            L(block: .paragraph, runs: [R(text: "We "), R(text: "finally", bold: true), R(text: " went, "), R(text: "all of us", italic: true), R(text: ".")]),
            L(block: .bullet, runs: [R(text: "penguins")]),
            L(block: .bullet, runs: [R(text: "the "), R(text: "old", strike: true), R(text: " new carousel")]),
            L(block: .quote, runs: [R(text: "Can we come back?", bold: true, italic: true)]),
            L(),
        ]
        let md = MemoText.markdown(lines)
        #expect(md == "# Sunday\nWe **finally** went, *all of us*.\n- penguins\n- the ~~old~~ new carousel\n> ***Can we come back?***\n")
        #expect(MemoText.parse(md) == lines)
    }

    @Test func markersNeverWrapEdgeSpaces() {
        let md = MemoText.markdown([L(runs: [R(text: "a"), R(text: " bold ", bold: true), R(text: "b")])])
        #expect(md == "a **bold** b")
        #expect(MemoText.parse(md) == [L(runs: [R(text: "a "), R(text: "bold", bold: true), R(text: " b")])])
    }

    @Test func literalMarkCharactersSurvive() {
        let lines = [L(runs: [R(text: "2*3*4 and snake_case ~ `x` [y]")]), L(runs: [R(text: "# not a heading")]), L(runs: [R(text: "- not a list")])]
        let md = MemoText.markdown(lines)
        #expect(MemoText.parse(md) == lines)
        #expect(MemoText.plain(md) == "2*3*4 and snake_case ~ `x` [y]\n# not a heading\n- not a list")
    }

    @Test func plainShowsBulletsAndDropsMarks() {
        #expect(MemoText.plain("# Day\n**Big** *day*\n- one\n> said") == "Day\nBig day\n• one\nsaid")
    }

    /// The same answers as the web's reader (tests/memo_text.test.mjs).
    @Test func sharedCasesMatchTheWeb() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../tests/fixtures/memo-text.json").standardized
        struct File: Decodable { struct C: Decodable { let md, plain: String }; let cases: [C] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        #expect(file.cases.count >= 6)
        for c in file.cases { #expect(MemoText.plain(c.md) == c.plain, "\(c.md)") }
    }
}
