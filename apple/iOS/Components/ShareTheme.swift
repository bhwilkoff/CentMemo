#if os(iOS) || os(macOS)
import SwiftUI

/// N4 (DESIGN S6): a whole theme as one card, designed by the person. Any memo can be
/// left out; Lines is made of the words they underline in each.
struct ShareThemeSheet: View {
    let theme: String
    let entries: [LedgerEntry]
    @State private var design = ThemeShareDesign()
    @State private var left: Set<String> = []
    @State private var marks: [String: ClosedRange<Int>] = [:]
    @State private var room: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private func memo(_ e: LedgerEntry) -> ThemeShareContent.Memo {
        .init(id: e.id, memo: MemoText.plain(e.memo?.body ?? ""), setting: e.displayMerchant, date: LedgerDate.display(e.txnDate), day: e.txnDate, mark: marks[e.id])
    }

    private var content: ThemeShareContent {
        let c = Themes.hex[Themes.colorKey(theme)] ?? (0x6F6964, 0xB3ACA6)
        let memos = entries.filter { !left.contains($0.id) }.map(memo), days = memos.map(\.day).sorted()
        let span = days.first.map { a in a == days.last ? LedgerDate.display(a) : "\(LedgerDate.display(a)) to \(LedgerDate.display(days.last ?? a))" } ?? ""
        return ThemeShareContent(theme: .init(name: theme, paper: c.0, night: c.1), span: span, memos: memos)
    }

    var body: some View {
        ShareStudio(title: "Share this theme", shape: design.shape, card: { ThemeShareCard(content: content, design: design) },
                    choices: { choices }, send: { send })
    }

    private var send: some View {
        ShareLink(item: SharedPicture(render: { [content, design] in try SharedPicture.png(ThemeShareCard(content: content, design: design)) }),
                  preview: SharePreview(theme)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(content.memos.isEmpty)
        .accessibilityIdentifier("share-theme-send")
    }

    @ViewBuilder private var choices: some View {
        Section("Look") {
            Picker("Look", selection: $design.look) {
                Text("Cover").tag(ThemeShareDesign.Look.cover)
                Text("Pages").tag(ThemeShareDesign.Look.pages)
                Text("Lines").tag(ThemeShareDesign.Look.lines)
            }
            .pickerStyle(.segmented).labelsHidden()
        }
        if design.look == .pages { PencilPicker(pencil: $design.pencil) }
        SharePaperAndShape(paper: $design.paper, shape: $design.shape, hasTheme: true)
        Section("Show") {
            Toggle("Where", isOn: $design.showSetting).accessibilityIdentifier("share-theme-place")
            Toggle("When", isOn: $design.showDate)
        }
        Section {
            ForEach(entries) { e in
                let m = memo(e), on = !left.contains(e.id)
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Toggle(isOn: Binding(get: { on }, set: { if $0 { left.remove(e.id) } else { left.insert(e.id) } })) {
                        Text("\(m.setting), \(m.date)").font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    }
                    if on { ShareWords(words: m.words, mark: Binding(get: { marks[e.id] }, set: { marks[e.id] = $0 }), prefix: e.id) }
                }
            }
        } header: {
            Text("Mark the words that matter")
        }
    }
}
#endif
