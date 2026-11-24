#if os(iOS) || os(macOS)
import SwiftUI

/// Home: purchases with no memo yet, newest first (money-story-design).
struct UnexaminedView: View {
    @Environment(SessionStore.self) private var session
    @State private var entries: [LedgerEntry] = []
    @State private var picked: [(APIClient.Suggestion, LedgerEntry)] = []
    @State private var shown = 0
    @State private var hasAny = true
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            if entries.isEmpty {
                if hasAny {
                    ContentUnavailableView("Every purchase has a memo.", systemImage: "checkmark")
                } else {
                    ContentUnavailableView {
                        Label("Nothing in your Narrative yet", systemImage: "tray")
                    } description: {
                        Text("Import an Apple Card export to start writing.")
                    } actions: {
                        ImportButton()
                    }
                }
            } else {
                List {
                    // D7: one invitation at a time, with its reason; "Another" shows the
                    // next of up to three. No count of what is left (no to-do lists).
                    if !picked.isEmpty {
                        let (s, e) = picked[shown % picked.count]
                        Section {
                            EntryLink(id: e.id) { SuggestionCard(suggestion: s, entry: e) }
                                .skipAction(e) { await skip(e) }
                                // In the card's corner, beside the reason (Ben, 2026-11-23: "within
                                // the card as well"). An overlay, not a child, so it never opens the event.
                                .overlay(alignment: .topTrailing) {
                                    if picked.count > 1 {
                                        Button("Another suggestion", systemImage: "arrow.clockwise") {
                                            shown += 1
                                            Haptic.selection()
                                        }
                                        .labelStyle(.iconOnly)
                                        .buttonStyle(.borderless)
                                        .font(TypeRamp.bodyStrong).foregroundStyle(Color.brandPrimary)
                                        .frame(width: 44, height: 44)
                                        .padding(.top, Spacing.s1).padding(.trailing, Spacing.s1)
                                        .accessibilityIdentifier("suggestion-another")
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: Spacing.s1, leading: PaneEdges.box, bottom: Spacing.s3, trailing: PaneEdges.box))
                        }
                    }
                    ForEach(entries) { e in
                        EntryLink(id: e.id) { EntryRow(entry: e) }.onGround().columnRowInsets()
                            .skipAction(e) { await skip(e) }
                    }
                }
                .listStyle(.plain)
                .opensFirst(picked.first?.1.id ?? entries.first?.id)
            }
        }
        .grounded()
        .navigationTitle("Unexamined")
        .refreshable { await load() }
        .task(id: session.dataVersion) { await load() }
    }

    /// Suggestions are a garnish: if they fail to load, the list still shows.
    private func suggestionsFor(_ list: [LedgerEntry]) async -> [(APIClient.Suggestion, LedgerEntry)] {
        guard let found = try? await APIClient.shared.suggestions() else { return [] }
        var out: [(APIClient.Suggestion, LedgerEntry)] = []
        for s in found.prefix(3) {
            if let e = list.first(where: { $0.id == s.transactionID }) { out.append((s, e)) }
            else if let e = try? await APIClient.shared.transaction(s.transactionID) { out.append((s, e)) }
        }
        return out
    }

    private func skip(_ e: LedgerEntry) async {
        entries.removeAll { $0.id == e.id }
        picked.removeAll { $0.1.id == e.id }
        do { try await APIClient.shared.setSkipped(e.id, true); session.didChangeData() }
        catch { self.error = session.handle(error); await load() }
    }

    private func load() async {
        loading = true
        do {
            // The list and its suggestions arrive together, so at regular width the
            // first suggestion (not the first row) opens on the right.
            let list = try await APIClient.shared.unexamined()
            picked = await suggestionsFor(list)
            entries = list
            if entries.isEmpty { hasAny = try await APIClient.shared.hasAnyTransactions() }
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }
}

/// Every transaction in a month, with the month's totals as plain facts.
struct LedgerView: View {
    @Environment(SessionStore.self) private var session
    @State private var showSkipped = false
    @State private var filter = NarrativeFilter()
    @State private var month: String?
    @State private var entries: [LedgerEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            List {
                if let month {
                    // The month bar is a row, so it stands on the same edges as every
                    // other row (as a section header it ran past the column's edge).
                    HStack {
                        Button { step(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(LedgerDate.monthName(month)).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                        Spacer()
                        Button { step(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next month")
                    }
                    .buttonStyle(.borderless)
                    .onGround().listRowSeparator(.hidden).columnRowInsets()
                    totals.onGround().columnRowInsets()
                    let parts = ThemeStrip.parts(entries)
                    if !parts.isEmpty {
                        MonthStrip(parts: parts).onGround().listRowSeparator(.hidden).columnRowInsets()
                    }
                }
                if entries.isEmpty {
                    Text("Nothing recorded this month.").foregroundStyle(Color.brandTextMuted).onGround()
                } else {
                    ForEach(filter.apply(entries)) { e in
                        EntryLink(id: e.id) { ThreadRow(entry: e) }.onGround()
                            .listRowSeparator(.hidden)
                            .columnRowInsets(vertical: 0)
                            .skipAction(e) { await skip(e, !e.isSkipped) }
                    }
                    let quiet = entries.filter { !$0.isSkipped && $0.isQuietDetail }.count
                    if quiet > 0 {
                        Button { withAnimation { filter.details.toggle() } } label: {
                            Text(filter.details ? "Hide deposits and interest" : "\(quiet) deposits and interest hidden · Show")
                                .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                        .buttonStyle(.plain).onGround().listRowSeparator(.hidden).columnRowInsets()
                        .accessibilityIdentifier("quiet-details")
                    }
                    let skipped = entries.filter(\.isSkipped)
                    if !skipped.isEmpty {
                        // Separate rows (not a DisclosureGroup, whose children share one
                        // cell and cannot take their own swipe).
                        Section {
                            if showSkipped {
                                ForEach(skipped) { e in
                                    EntryLink(id: e.id) { EntryRow(entry: e).opacity(0.6) }.onGround().columnRowInsets()
                                        .skipAction(e) { await skip(e, false) }
                                }
                            }
                        } header: {
                            Button { withAnimation { showSkipped.toggle() } } label: {
                                Label("\(skipped.count) skipped", systemImage: showSkipped ? "chevron.down" : "chevron.right")
                                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .opensFirst(entries.first { !$0.isSkipped && !$0.isQuietDetail }?.id)
        }
        .grounded()
        .navigationTitle("Narrative")
        // D9: show only some kinds of events (a native filter menu).
        .toolbar {
            ToolbarItem(placement: .mainAction) {
                Menu {
                    Picker("Show", selection: $filter.show) {
                        ForEach(NarrativeFilter.Show.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    let themes = Array(Set(entries.flatMap { $0.memo?.valueNames ?? [] })).sorted()
                    if !themes.isEmpty {
                        Picker("Theme", selection: $filter.theme) {
                            Text("Every theme").tag(String?.none)
                            ForEach(themes, id: \.self) { Text($0).tag(String?.some($0)) }
                        }
                    }
                    Toggle("Include deposits and interest", isOn: $filter.details)
                } label: {
                    Image(systemName: filter.isDefault ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter")
                .accessibilityIdentifier("narrative-filter")
            }
        }
        .refreshable { await load() }
        .task(id: "\(session.dataVersion)-\(month ?? "")") { await load() }
    }

    private var totals: some View {
        let live = entries.filter { $0.status != "rejected" }
        let spent = live.filter { $0.amountMinor < 0 }.reduce(0) { $0 - $1.amountMinor }
        let received = live.filter { $0.amountMinor > 0 }.reduce(0) { $0 + $1.amountMinor }
        let written = entries.filter { $0.memo != nil }.count
        return HStack(alignment: .top) {
            fact("Spent", Money.format(spent))
            fact("Paid or credited", Money.format(received))
            fact("Memos", "\(written) of \(entries.count)")
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
            Text(value).font(TypeRamp.bodyStrong).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(_ n: Int) {
        guard let month else { return }
        self.month = LedgerDate.step(month, by: n)
        Haptic.selection()
    }

    private func skip(_ e: LedgerEntry, _ skipped: Bool) async {
        do { try await APIClient.shared.setSkipped(e.id, skipped); session.didChangeData() }
        catch { self.error = session.handle(error) }
    }

    private func load() async {
        loading = true
        do {
            if month == nil { month = try await APIClient.shared.latestMonth() ?? LedgerDate.thisMonth }
            entries = try await APIClient.shared.month(month!)
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }
}

/// DESIGN C3.2: the values a person names wear their color. Static chips (in
/// the story) are always filled; on a memo, unselected ones are outlined.
struct ValueChip: View {
    @Environment(SessionStore.self) private var session
    let name: String
    let isOn: Bool
    var isStatic = false
    var body: some View {
        let filled = isOn || isStatic
        Text(name)
            .font(TypeRamp.caption)
            .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s1)
            .background(filled ? session.ground.color : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(filled ? Color.clear : Color.brandBorder))
            .foregroundStyle(filled ? Ground.onColor : Color.brandText)
    }
}
#endif
