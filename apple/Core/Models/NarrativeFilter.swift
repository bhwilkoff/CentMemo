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
