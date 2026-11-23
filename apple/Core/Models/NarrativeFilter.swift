import Foundation

/// D9: show only some kinds of events in the Narrative. The same rule as the
/// web's narrativeFilter (js/app.js). Skipped events are always apart.
struct NarrativeFilter: Equatable, Sendable {
    enum Show: String, CaseIterable, Sendable { case all = "All", written = "Written", unwritten = "Unwritten" }
    var show: Show = .all
    var theme: String? = nil
    /// Deposits and interest: quiet by default (Ben, 2026-11-22).
    var details = false

    var isDefault: Bool { self == NarrativeFilter() }

    func apply(_ entries: [LedgerEntry]) -> [LedgerEntry] {
        entries.filter { e in
            guard !e.isSkipped else { return false }
            if !details && e.isQuietDetail { return false }
            switch show {
            case .all: break
            case .written: if e.memo == nil { return false }
            case .unwritten: if e.memo != nil { return false }
            }
            if let theme { return e.memo?.valueNames.contains(theme) == true }
            return true
        }
    }
}

/// D11: how a month's written memos divide among themes, by money spent, for the
/// month strip. A memo counts under its first theme only, so the parts add up to
/// the whole. Same rule as js/app.js themeStrip.
enum ThemeStrip {
    struct Part: Equatable, Sendable { let theme: String; let spentMinor: Int }

    static func parts(_ entries: [LedgerEntry]) -> [Part] {
        var sums: [String: Int] = [:]
        for e in entries where !e.isSkipped && e.amountMinor < 0 {
            guard let theme = e.memo?.valueNames.first else { continue }
            sums[theme, default: 0] -= e.amountMinor
        }
        return sums.map { Part(theme: $0.key, spentMinor: $0.value) }
            .sorted { $0.spentMinor != $1.spentMinor ? $0.spentMinor > $1.spentMinor : $0.theme < $1.theme }
    }
}
