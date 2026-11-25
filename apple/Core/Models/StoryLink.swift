import Foundation

/// A story link being made (DESIGN S7, Decision 067). It holds no amount, and the
/// store and date of a Wallet purchase are never filled in for the writer. What is
/// published is decided in the database (make_share); the web's twin is linkPanel.
nonisolated struct StoryLinkDraft: Equatable, Sendable {
    enum Kind: String, Encodable, Sendable { case memo, theme }
    enum Paper: String, CaseIterable, Encodable, Sendable {
        case bold, paper, night
        var title: String { switch self { case .bold: "Bold"; case .paper: "Paper"; case .night: "Night" } }
    }
    enum Pencil: String, CaseIterable, Encodable, Sendable {
        case underline, double, circle, highlight
        var title: String { switch self { case .underline: "Underline"; case .double: "Two lines"; case .circle: "Circle"; case .highlight: "Highlight" } }
    }
    enum Lead: String, CaseIterable, Encodable, Sendable {
        case memory, setting, theme
        var title: String { switch self { case .memory: "The memory"; case .setting: "The place"; case .theme: "The theme" } }
    }
    struct Item: Equatable, Sendable, Identifiable {
        var id: String
        var memo: String
        /// What the app shows the writer, to tell the memos apart; never published.
        var shown: String
        var shownWhen: String
        var place = ""
        var when = ""
        var mark: ClosedRange<Int>?
        var on = true
        var wallet = true
        var words: [String] { memo.split(whereSeparator: \.isWhitespace).map(String.init) }
    }
    struct Theme: Equatable, Sendable { var id: String; var name: String; var color: String }

    var kind: Kind
    var theme: Theme?
    var items: [Item]
    var sharedBy = ""
    var paper = Paper.bold
    var pencil = Pencil.underline
    var lead = Lead.memory
    var showPlace = true, showWhen = true, showTheme = true
    var cover = true, lines = true, mems = true

    var chosen: [Item] { items.filter(\.on) }
    /// What stops a link, in words; nil when one can be made.
    var problem: String? {
        if chosen.isEmpty { return "Choose at least one memo." }
        if kind == .theme, !cover, !lines, !mems { return "Choose at least one part of the page." }
        return nil
    }

    /// Once it is known which purchases came from Wallet, the rest may start with
    /// their place and date, where the writer has typed nothing.
    mutating func fill(wallet: Set<String>) {
        for i in items.indices {
            items[i].wallet = wallet.contains(items[i].id)
            guard !items[i].wallet else { continue }
            if items[i].place.isEmpty { items[i].place = items[i].shown }
            if items[i].when.isEmpty { items[i].when = items[i].shownWhen }
        }
    }

    // MARK: What is sent, and what the preview draws

    struct Design: Encodable, Sendable {
        let color: String, paper: Paper, pencil: Pencil, lead: Lead
        let place, when, theme, cover, lines, mems: Bool
    }
    struct Request: Encodable, Sendable {
        struct Item: Encodable, Sendable { let txn, place, when: String; let mark: [Int]? }
        let p_kind: Kind, p_items: [Item], p_design: Design, p_value: String?, p_from: String?
    }
    struct Preview: Encodable, Sendable {
        struct Item: Encodable, Sendable { let memo: String; let place, when: String?; let mark: [Int]? }
        struct Named: Encodable, Sendable { let name: String }
        let kind: Kind, theme: Named?, from: String?, items: [Item], design: Design
    }
    private static func tidy(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
    private static func pair(_ m: ClosedRange<Int>?) -> [Int]? { m.map { [$0.lowerBound, $0.upperBound] } }
    private var design: Design {
        .init(color: theme?.color ?? "clay", paper: paper, pencil: pencil, lead: lead, place: showPlace, when: showWhen,
              theme: showTheme, cover: cover, lines: lines, mems: mems)
    }
    var request: Request {
        .init(p_kind: kind, p_items: chosen.map { .init(txn: $0.id, place: $0.place, when: $0.when, mark: Self.pair($0.mark)) },
              p_design: design, p_value: theme?.id, p_from: Self.tidy(sharedBy))
    }
    var preview: Preview {
        .init(kind: kind, theme: kind == .theme || showTheme ? theme.map { .init(name: $0.name) } : nil, from: Self.tidy(sharedBy),
              items: chosen.map { .init(memo: $0.memo, place: showPlace ? Self.tidy($0.place) : nil, when: showWhen ? Self.tidy($0.when) : nil, mark: Self.pair($0.mark)) },
              design: design)
    }
}

/// A link the person made, as Settings lists it.
nonisolated struct StoryLink: Decodable, Identifiable, Hashable, Sendable {
    let code: String
    let title: String
    let createdAt: String
    var id: String { code }
    var url: URL { Self.url(code) }
    static func url(_ code: String) -> URL { URL(string: "https://centmemo.com/s/#" + code)! }
    enum CodingKeys: String, CodingKey { case code, title, createdAt = "created_at" }
}
