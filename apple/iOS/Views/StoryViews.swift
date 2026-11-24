#if os(iOS) || os(macOS)
import SwiftUI

struct ThemeShareItem: Identifiable { let name: String; var id: String { name } }

/// What the Story shows now: a month, or one theme. Shared by the shelf and the
/// reading column, which stand apart at medium and wide (DESIGN W4).
@Observable final class StoryModel {
    var scope: APIClient.StoryScope?
    var months: [String] = []
    var values: [LifeValue] = []
    var counts: [String: Int] = [:]
    var entries: [LedgerEntry] = []
    var loading = true
    var error: String?

    var themeID: String? { if case .value(let id) = scope { id } else { nil } }
    var themeName: String? { themeID.flatMap { id in values.first { $0.id == id }?.name } }
    /// Themes are the Story's collections (Decision 065): the ones that hold memos.
    var shelf: [LifeValue] { values.filter { (counts[$0.id] ?? 0) > 0 } }
    var title: String {
        if let themeName { return themeName }
        if case .month(let m) = scope { return LedgerDate.monthName(m) }
        return "Story"
    }
    func everyMemo() { scope = .month(months.first ?? LedgerDate.thisMonth) }

    func load(_ session: SessionStore) async {
        loading = true
        do {
            let latest = try await APIClient.shared.latestMonth() ?? LedgerDate.thisMonth
            months = (0..<24).map { LedgerDate.step(latest, by: -$0) }
            values = try await APIClient.shared.values()
            counts = (try? await APIClient.shared.themeCounts()) ?? [:]
            if scope == nil { scope = .month(latest) }
            entries = try await APIClient.shared.stories(scope!)
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }
}

/// The Story, read in order. Compact: one list that pushes. Medium and wide: the
/// shelf beside the reading column. The Mac places the two in its own columns.
struct StoryView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.horizontalSizeClass) private var width
    @State private var model = StoryModel()

    var body: some View {
        LoadState(isLoading: model.loading && model.entries.isEmpty, error: model.error, retry: { await model.load(session) }) {
            if width == .regular {
                HStack(spacing: 0) {
                    List { StoryShelf(model: model) }.listStyle(.plain).frame(width: 320)
                    Divider()
                    StoryReading(model: model)
                }
            } else {
                List {
                    StoryShelf(model: model)
                    if model.entries.isEmpty {
                        Text("No memos here yet.").foregroundStyle(Color.brandTextMuted).onGround().columnRowInsets()
                    }
                    ForEach(model.entries) { e in
                        EntryLink(id: e.id) { StoryCard(entry: e) }
                            // A card on the box edge (16pt), its words 16pt inside it (DESIGN L2).
                            .listRowBackground(RoundedRectangle(cornerRadius: Radius.card).fill(Color.brandSurface).padding(.vertical, 4).padding(.horizontal, PaneEdges.box))
                            .listRowInsets(EdgeInsets(top: Spacing.s3, leading: PaneEdges.box * 2, bottom: Spacing.s3, trailing: PaneEdges.box * 2))
                    }
                }
                .listStyle(.plain)
            }
        }
        .grounded()
        .navigationTitle("Story")
        .modifier(StoryChrome(model: model))
    }
}

/// The Story's share button and its loading, wherever its parts are placed.
struct StoryChrome: ViewModifier {
    let model: StoryModel
    @Environment(SessionStore.self) private var session
    @State private var sharingTheme: String?
    @State private var linkingTheme: LifeValue?
    func body(content: Content) -> some View {
        content
            .toolbar {
                // D12: a whole theme as one card, when the Story shows one theme.
                if let name = model.themeName, !model.entries.isEmpty {
                    Button("Share this theme", systemImage: "square.and.arrow.up") { sharingTheme = name }
                        .accessibilityIdentifier("share-theme")
                    Button("Make a link to this theme", systemImage: "link") { linkingTheme = model.values.first { $0.id == model.themeID } }
                        .accessibilityIdentifier("link-theme")
                }
            }
            .sheet(item: Binding(get: { sharingTheme.map(ThemeShareItem.init) }, set: { sharingTheme = $0?.name })) { item in
                ShareThemeSheet(theme: item.name, entries: model.entries)
            }
            .sheet(item: $linkingTheme) { MakeLinkSheet(theme: $0, entries: model.entries) }
            .task(id: "\(session.dataVersion)-\(String(describing: model.scope))") { await model.load(session) }
    }
}

/// The shelf: the themes that hold memos, then the month.
struct StoryShelf: View {
    @Bindable var model: StoryModel

    var body: some View {
        if !model.shelf.isEmpty {
            Section {
                ForEach(model.shelf) { v in
                    let on = model.themeID == v.id
                    Button { if on { model.everyMemo() } else { model.scope = .value(v.id) } } label: {
                        HStack(spacing: Spacing.s3) {
                            Capsule().fill(ThemeHue.color(v.name)).frame(width: 4, height: 22)
                            Text(v.name).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                            Spacer()
                            Text("\(model.counts[v.id] ?? 0)").font(TypeRamp.caption).monospacedDigit().foregroundStyle(Color.brandTextMuted)
                            if on { Image(systemName: "checkmark").foregroundStyle(Color.brandPrimary) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("theme-\(v.name)")
                    .onGround().columnRowInsets()
                }
            } header: {
                Text("Themes").font(TypeRamp.caption).textCase(nil)
            }
        }
        Section {
            if model.themeID == nil {
                Picker("Month", selection: Binding(get: { model.scope ?? .month(LedgerDate.thisMonth) }, set: { model.scope = $0 })) {
                    ForEach(model.months, id: \.self) { Text(LedgerDate.monthName($0)).tag(APIClient.StoryScope.month($0)) }
                }
                .columnRowInsets()
            } else {
                Button("Every memo") { model.everyMemo() }
                    .accessibilityIdentifier("every-memo")
                    .columnRowInsets()
            }
            if !model.entries.isEmpty {
                Text("\(model.entries.count) \(model.entries.count == 1 ? "memo" : "memos")")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    .columnRowInsets()
            }
        }
        .onGround()
    }
}

/// D6: the memo is the headline; when, where and how much are its footnote.
struct StoryCard: View {
    let entry: LedgerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(entry.memo?.body ?? "").font(DisplayType.memo).foregroundStyle(Color.brandText)
            if let names = entry.memo?.valueNames, !names.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(names, id: \.self) { ValueChip(name: $0, isOn: false, isStatic: true) }
                }
            }
            HStack {
                Text("\(LedgerDate.display(entry.txnDate)) · \(entry.displayMerchant)")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                Spacer()
                MoneyText(minor: entry.amountMinor, currency: entry.currency, font: TypeRamp.caption)
            }
        }
        .padding(.vertical, Spacing.s1)
    }
}

/// W4, W5: the memos as a page, one column no wider than reading allows.
struct StoryReading: View {
    let model: StoryModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s8) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    if let name = model.themeName {
                        Capsule().fill(ThemeHue.color(name)).frame(width: 40, height: 4)
                    }
                    Text(model.title).font(DisplayType.title).foregroundStyle(Color.brandPrimary)
                }
                .accessibilityAddTraits(.isHeader)
                if model.entries.isEmpty {
                    Text("No memos here yet.").foregroundStyle(Color.brandTextMuted)
                }
                ForEach(model.entries) { e in
                    EntryLink(id: e.id) { page(e) }.buttonStyle(.plain)
                }
            }
            .frame(maxWidth: Room.measure, alignment: .leading)
            .padding(.horizontal, PaneEdges.pane)
            .padding(.vertical, Spacing.s8)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("story-reading")
    }

    private func page(_ e: LedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(e.memo?.body ?? "").font(DisplayType.memo).foregroundStyle(Color.brandText).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.s3) {
                StoreTile(name: e.displayMerchant, category: e.category, size: 28)
                Text("\(e.displayMerchant) · \(LedgerDate.display(e.txnDate))")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                if let names = e.memo?.valueNames, model.themeID == nil {
                    ForEach(names.prefix(2), id: \.self) { n in
                        HStack(spacing: 4) {
                            Capsule().fill(ThemeHue.color(n)).frame(width: 12, height: 3)
                            Text(n).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
#endif
