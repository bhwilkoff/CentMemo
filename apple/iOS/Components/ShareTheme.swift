#if os(iOS)
import SwiftUI

/// D12: share a whole theme as one card: its name and mark, and the memos the
/// person keeps in it. Private by default, like the memo card: places and
/// amounts stay off, and the person can leave any memo out. The card is an
/// image made on this phone; CentMemo publishes nothing.
struct ThemeShareCard: View {
    let theme: String
    let entries: [LedgerEntry]
    var showPlace = false
    var showAmount = false
    static let maxOnCard = 6

    private let ink = Color(red: 0.137, green: 0.106, blue: 0.11)
    private let muted = Color(red: 0.37, green: 0.33, blue: 0.33)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(spacing: 8) {
                Capsule().fill(ThemeHue.color(theme)).frame(width: 5, height: 28)
                Text(theme).font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(ink)
            }
            ForEach(entries.prefix(Self.maxOnCard)) { e in
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.memo?.body ?? "").font(.system(size: 19, design: .serif)).foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(([LedgerDate.display(e.txnDate)] + (showPlace ? [e.displayMerchant] : []) + (showAmount ? [Money.format(-e.amountMinor)] : []))
                        .joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(muted)
                }
            }
            if entries.count > Self.maxOnCard {
                Text("and \(entries.count - Self.maxOnCard) more").font(.system(size: 13)).foregroundStyle(muted)
            }
            Text("CentMemo").font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.29, green: 0.08, blue: 0.125))
        }
        .padding(28)
        .frame(width: 360, alignment: .leading)
        .background(Color(red: 0.984, green: 0.98, blue: 0.969))
        .environment(\.colorScheme, .light)
    }
}

struct ShareThemeSheet: View {
    let theme: String
    let entries: [LedgerEntry]
    @State private var left: Set<String> = []
    @State private var showPlace = false
    @State private var showAmount = false
    @Environment(\.dismiss) private var dismiss

    private var included: [LedgerEntry] { entries.filter { !left.contains($0.id) } }
    private var card: ThemeShareCard { ThemeShareCard(theme: theme, entries: included, showPlace: showPlace, showAmount: showAmount) }
    private var image: Image {
        let r = ImageRenderer(content: card)
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "photo")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { card.frame(maxWidth: .infinity).listRowBackground(Color.clear) }
                Section {
                    ForEach(entries) { e in
                        Toggle(isOn: Binding(get: { !left.contains(e.id) },
                                             set: { if $0 { left.remove(e.id) } else { left.insert(e.id) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.memo?.body ?? "").lineLimit(2)
                                Text(LedgerDate.display(e.txnDate)).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                            }
                        }
                    }
                } header: {
                    Text("Memos on the card")
                }
                Section {
                    Toggle("Show where", isOn: $showPlace).accessibilityIdentifier("share-theme-place")
                    Toggle("Show the amounts", isOn: $showAmount).accessibilityIdentifier("share-theme-amount")
                } footer: {
                    Text("Only the theme, its memos, and their dates are shared unless you turn these on.")
                }
                Section {
                    ShareLink(item: image, preview: SharePreview(theme, image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(included.isEmpty)
                    .accessibilityIdentifier("share-theme-send")
                }
            }
            .navigationTitle("Share this theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
