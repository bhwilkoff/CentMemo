import Foundation

/// D14: the starter themes Ben approved (tests/fixtures/starter-themes.json is
/// the source; ThemesTests holds this copy to it) and the rule that gives each
/// theme its own color. The web's twin is js/money/themes.js; both share a golden.
enum Themes {
    struct Starter: Equatable, Sendable { let name: String; let meaning: String; let color: String }

    nonisolated static let palette = ["clay", "persimmon", "ochre", "olive", "moss", "sage", "teal", "sky", "slate", "iris", "plum", "rose", "stone"]
    nonisolated static let starters: [Starter] = [
        .init(name: "People I love", meaning: "Time and care for family and friends.", color: "rose"),
        .init(name: "Great meals", meaning: "Food worth remembering, alone or shared.", color: "persimmon"),
        .init(name: "Home", meaning: "The place I live and the comfort in it.", color: "clay"),
        .init(name: "Health", meaning: "My body, rest, movement, and care.", color: "moss"),
        .init(name: "Learning", meaning: "Books, classes, tools that grow a skill.", color: "slate"),
        .init(name: "Making", meaning: "Materials and tools for things I create.", color: "ochre"),
        .init(name: "Adventure", meaning: "Trips, firsts, and getting out of routine.", color: "sky"),
        .init(name: "Joy", meaning: "Small treats and beautiful things that make a day better.", color: "plum"),
        .init(name: "Generosity", meaning: "Gifts, tips, and giving to causes.", color: "iris"),
        .init(name: "Time back", meaning: "Paying so I can spend time on what matters.", color: "teal"),
        .init(name: "Work I care about", meaning: "Tools and costs of my work or craft.", color: "olive"),
        .init(name: "Community", meaning: "Local places, events, and belonging.", color: "sage"),
        .init(name: "Taking care of things", meaning: "The steady costs that keep life running.", color: "stone"),
    ]

    /// The signed-in person's theme colors, refreshed whenever their themes load.
    static var current: [String: String] = [:]

    /// The color a theme shows: its assigned one, else a starter's, else a
    /// stable pick from the palette (a name seen before the themes loaded).
    static func colorKey(_ name: String) -> String {
        let k = key(name)
        return current[k] ?? starters.first(where: { key($0.name) == k })?.color
            ?? palette[Money.merchantHue(k, count: palette.count)]
    }

    /// The color a new theme stores when it is created: its starter color if no
    /// theme shows it, else the first color none shows. Stored, so adding a
    /// theme never shifts the colors the person already sees.
    nonisolated static func nextColor(_ themes: [Input], name: String) -> String {
        let shown = Set(assignColors(themes).values)
        if let s = starters.first(where: { key($0.name) == key(name) }), !shown.contains(s.color) { return s.color }
        return palette.first { !shown.contains($0) } ?? palette[themes.count % palette.count]
    }

    static func nextColor(joining held: [LifeValue], name: String) -> String {
        nextColor(held.map { .init(name: $0.name, color: $0.color, createdAt: $0.createdAt ?? "") }, name: name)
    }

    struct Input: Sendable { let name: String; var color: String? = nil; var createdAt: String = "" }

    nonisolated static func key(_ name: String) -> String { name.trimmingCharacters(in: .whitespaces).lowercased() }

    /// 1. A color the person chose stays. 2. A starter theme's name takes the
    /// starter's color. 3. Everything else, oldest first, takes the first palette
    /// color no theme holds yet. Past 13 themes, colors repeat in palette order.
    nonisolated static func assignColors(_ themes: [Input]) -> [String: String] {
        let list = themes.sorted { ($0.createdAt, key($0.name)) < ($1.createdAt, key($1.name)) }
        var out: [String: String] = [:]
        var used = Set<String>()
        func take(_ t: Input, _ c: String) { out[key(t.name)] = c; used.insert(c) }
        for t in list where out[key(t.name)] == nil { if let c = t.color, palette.contains(c) { take(t, c) } }
        for t in list where out[key(t.name)] == nil {
            if let s = starters.first(where: { key($0.name) == key(t.name) }), !used.contains(s.color) { take(t, s.color) }
        }
        var spill = 0
        for t in list where out[key(t.name)] == nil {
            if let free = palette.first(where: { !used.contains($0) }) { take(t, free) }
            else { take(t, palette[spill % palette.count]); spill += 1 }
        }
        return out
    }
}
