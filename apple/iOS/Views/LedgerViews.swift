#if os(iOS)
import SwiftUI

/// Home: purchases with no memo yet, newest first (money-story-design).
struct UnexaminedView: View {
    @Environment(SessionStore.self) private var session
    @State private var entries: [LedgerEntry] = []
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
                        Label("No transactions yet", systemImage: "tray")
                    } description: {
                        Text("Import an Apple Card export to start writing.")
                    } actions: {
                        ImportButton()
                    }
                }
            } else {
                List {
                    // DESIGN C3.1 + C4: the count is this screen's one bold mark.
                    HStack(spacing: Spacing.s2) {
                        Text("\(entries.count)")
                            .font(TypeRamp.bodyStrong).monospacedDigit()
                            .foregroundStyle(Ground.onColor)
                            .padding(.horizontal, 10).padding(.vertical, 2)
                            .background(session.ground.color, in: Capsule())
                            // DESIGN M1: circled in sanguine pencil, like the web.
                            .overlay(PencilCircle().stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .padding(-6))
                            .padding(6)
                            .accessibilityLabel("\(entries.count) unexamined")
                        Text(entries.count == 1 ? "purchase waiting for a memo" : "purchases waiting for a memo")
                            .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    }
                    .onGround()
                    ForEach(entries) { e in
                        EntryLink(id: e.id) { EntryRow(entry: e) }.onGround()
                    }
                }
                .listStyle(.plain)
                .opensFirst(entries.first?.id)
            }
        }
        .grounded()
        .navigationTitle("Unexamined")
        .refreshable { await load() }
        .task(id: session.dataVersion) { await load() }
    }

    private func load() async {
        loading = true
        do {
            entries = try await APIClient.shared.unexamined()
            if entries.isEmpty { hasAny = try await APIClient.shared.hasAnyTransactions() }
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }
}

/// Every transaction in a month, with the month's totals as plain facts.
struct LedgerView: View {
    @Environment(SessionStore.self) private var session
    @State private var month: String?
    @State private var entries: [LedgerEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            List {
                if let month {
                    Section {
                        totals.onGround()
                    } header: {
                        HStack {
                            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Previous month")
                            Spacer()
                            Text(LedgerDate.monthName(month)).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                            Spacer()
                            Button { step(1) } label: { Image(systemName: "chevron.right") }
                                .accessibilityLabel("Next month")
                        }
                        .textCase(nil)
                    }
                }
                if entries.isEmpty {
                    Text("Nothing recorded this month.").foregroundStyle(Color.brandTextMuted).onGround()
                } else {
                    ForEach(entries) { e in
                        EntryLink(id: e.id) { EntryRow(entry: e, showMemo: true) }.onGround()
                    }
                }
            }
            .listStyle(.plain)
            .opensFirst(entries.first?.id)
        }
        .grounded()
        .navigationTitle("Ledger")
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
        UISelectionFeedbackGenerator().selectionChanged()
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

/// The memos for a month or a value, in order, as a page to read.
struct StoryView: View {
    @Environment(SessionStore.self) private var session
    @State private var scope: APIClient.StoryScope?
    @State private var months: [String] = []
    @State private var values: [LifeValue] = []
    @State private var entries: [LedgerEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            List {
                Section {
                    Picker("Show", selection: Binding(get: { scope ?? .month(LedgerDate.thisMonth) }, set: { scope = $0 })) {
                        Section("Month") {
                            ForEach(months, id: \.self) { Text(LedgerDate.monthName($0)).tag(APIClient.StoryScope.month($0)) }
                        }
                        if !values.isEmpty {
                            Section("Value") {
                                ForEach(values) { Text($0.name).tag(APIClient.StoryScope.value($0.id)) }
                            }
                        }
                    }
                    if !entries.isEmpty {
                        let spent = entries.filter { $0.amountMinor < 0 }.reduce(0) { $0 - $1.amountMinor }
                        Text("\(entries.count) \(entries.count == 1 ? "memo" : "memos") · \(Money.format(spent)) spent")
                            .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    }
                }
                .onGround()
                if entries.isEmpty {
                    Text("No memos here yet.").foregroundStyle(Color.brandTextMuted).onGround()
                }
                ForEach(entries) { e in
                    EntryLink(id: e.id) {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            HStack {
                                Text("\(LedgerDate.display(e.txnDate)) · \(e.displayMerchant)")
                                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                                Spacer()
                                MoneyText(minor: e.amountMinor, currency: e.currency, font: TypeRamp.caption)
                            }
                            Text(e.memo?.body ?? "").font(DisplayType.memo)
                            if let names = e.memo?.valueNames, !names.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(names, id: \.self) { ValueChip(name: $0, isOn: false, isStatic: true) }
                                }
                            }
                        }
                        .padding(.vertical, Spacing.s1)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: Radius.card).fill(Color.brandSurface).padding(.vertical, 4).padding(.horizontal, Spacing.s3))
                }
            }
            .listStyle(.plain)
            .opensFirst(entries.first?.id)
        }
        .grounded()
        .navigationTitle("Story")
        .task(id: "\(session.dataVersion)-\(String(describing: scope))") { await load() }
    }

    private func load() async {
        loading = true
        do {
            let latest = try await APIClient.shared.latestMonth() ?? LedgerDate.thisMonth
            months = (0..<24).map { LedgerDate.step(latest, by: -$0) }
            values = try await APIClient.shared.values()
            if scope == nil { scope = .month(latest) }
            entries = try await APIClient.shared.stories(scope!)
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
