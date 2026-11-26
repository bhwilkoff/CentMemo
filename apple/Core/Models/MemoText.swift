import Foundation

/// W4 (Decision 069): a memo's styled text, kept in the memo column as a small Markdown
/// subset so Claude, the web and every old memo read it as plain words. Bold, italic,
/// strikethrough; a heading, a bulleted line, a quote. Never underline (it is the share's
/// pencil mark) and never HTML. One reader and one writer, proved by a round-trip test.
nonisolated enum MemoText {
    enum Block: String, Codable, Sendable { case paragraph, heading, bullet, quote }

    struct Run: Equatable, Sendable {
        var text: String
        var bold = false
        var italic = false
        var strike = false
    }

    struct Line: Equatable, Sendable {
        var block: Block = .paragraph
        var runs: [Run] = []
        var text: String { runs.map(\.text).joined() }
    }

    // MARK: Reading

    static func parse(_ markdown: String) -> [Line] {
        markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n").map(line)
    }

    private static func line(_ raw: String) -> Line {
        var block = Block.paragraph, rest = Substring(raw)
        for (prefix, kind) in [("## ", Block.heading), ("# ", .heading), ("- ", .bullet), ("* ", .bullet), ("> ", .quote)] where rest.hasPrefix(prefix) {
            block = kind
            rest = rest.dropFirst(prefix.count)
            break
        }
        return Line(block: block, runs: inline(String(rest)))
    }

    private static func inline(_ s: String) -> [Run] {
        guard !s.isEmpty else { return [] }
        let options = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: false, interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let a = try? AttributedString(markdown: s, options: options) else { return [Run(text: s)] }
        var runs: [Run] = []
        for r in a.runs {
            let intent = r.inlinePresentationIntent ?? []
            let run = Run(text: String(a[r.range].characters),
                          bold: intent.contains(.stronglyEmphasized), italic: intent.contains(.emphasized),
                          strike: intent.contains(.strikethrough))
            if let last = runs.last, last.bold == run.bold, last.italic == run.italic, last.strike == run.strike {
                runs[runs.count - 1].text += run.text
            } else if !run.text.isEmpty {
                runs.append(run)
            }
        }
        return runs
    }

    // MARK: Writing

    static func markdown(_ lines: [Line]) -> String {
        lines.map { l in
            let prefix: String = switch l.block {
            case .paragraph: ""
            case .heading: "# "
            case .bullet: "- "
            case .quote: "> "
            }
            var body = l.runs.map(write).joined()
            // A plain line that would read as a block marker keeps its characters.
            if l.block == .paragraph, let first = body.first, "#->".contains(first),
               body.hasPrefix("# ") || body.hasPrefix("## ") || body.hasPrefix("- ") || body.hasPrefix("> ") {
                body = "\\" + body
            }
            return prefix + body
        }.joined(separator: "\n")
    }

    private static func write(_ r: Run) -> String {
        let escaped = r.text.reduce(into: "") { out, c in
            if "\\*_~`[]<".contains(c) { out.append("\\") }
            out.append(c)
        }
        guard r.bold || r.italic || r.strike else { return escaped }
        // Markers must touch words: spaces at the edges stay outside them.
        let lead = String(escaped.prefix { $0 == " " }), trail = String(escaped.reversed().prefix { $0 == " " })
        let core = escaped.dropFirst(lead.count).dropLast(trail.count)
        guard !core.isEmpty else { return escaped }
        var open = ""
        if r.strike { open += "~~" }
        if r.bold { open += "**" }
        if r.italic { open += "*" }
        return lead + open + core + String(open.reversed()) + trail
    }

    // MARK: Reading on screen

    /// For a Text that shows the memo whole (the Story): marks as inline intents, which
    /// Text draws in the memo's own face; a heading is bold, a quote italic, a list item bulleted.
    static func styled(_ markdown: String) -> AttributedString {
        var out = AttributedString()
        for (i, l) in parse(markdown).enumerated() {
            if i > 0 { out += AttributedString("\n") }
            if l.block == .bullet { out += AttributedString("• ") }
            for r in l.runs {
                var piece = AttributedString(r.text)
                var intent: InlinePresentationIntent = []
                if r.bold || l.block == .heading { intent.insert(.stronglyEmphasized) }
                if r.italic || l.block == .quote { intent.insert(.emphasized) }
                if r.strike { intent.insert(.strikethrough) }
                if !intent.isEmpty { piece.inlinePresentationIntent = intent }
                out += piece
            }
        }
        return out
    }

    // MARK: Plain words

    /// The words without marks, for rows, search, and any place that shows one style.
    static func plain(_ markdown: String) -> String {
        parse(markdown).map { l in l.block == .bullet ? "• " + l.text : l.text }.joined(separator: "\n")
    }
}
