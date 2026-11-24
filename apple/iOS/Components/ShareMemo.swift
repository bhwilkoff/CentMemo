#if os(iOS) || os(macOS)
import SwiftUI

/// D12: share one memo as a card. Private by default (story-design-research):
/// the place stays off unless the
/// person turns it on, and an amount is never shared (Ben, 2026-11-24).
struct MemoShareCard: View {
    let entry: LedgerEntry
    let memo: String
    let theme: String?
    var showPlace = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text(memo).font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(Color(red: 0.137, green: 0.106, blue: 0.11))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                if let theme {
                    HStack(spacing: 6) {
                        Capsule().fill(ThemeHue.color(theme)).frame(width: 18, height: 4)
                        Text(theme).font(.system(size: 15, weight: .medium))
                    }
                }
                Text(([LedgerDate.display(entry.txnDate)] + (showPlace ? [entry.displayMerchant] : [])).joined(separator: " · "))
                    .font(.system(size: 15))
            }
            .foregroundStyle(Color(red: 0.37, green: 0.33, blue: 0.33))
            Text("CentMemo").font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.29, green: 0.08, blue: 0.125))
        }
        .padding(28)
        .frame(width: 360, alignment: .leading)
        // The card is paper and ink in either appearance: it is an image someone else sees.
        .background(Color(red: 0.984, green: 0.98, blue: 0.969))
        .environment(\.colorScheme, .light)
    }
}

struct ShareMemoSheet: View {
    let entry: LedgerEntry
    let memo: String
    let theme: String?
    @State private var showPlace = false
    @Environment(\.dismiss) private var dismiss

    private var card: MemoShareCard { MemoShareCard(entry: entry, memo: memo, theme: theme, showPlace: showPlace) }

    private var image: Image {
        let r = ImageRenderer(content: card)
        r.scale = 3
        return r.platformImage ?? Image(systemName: "photo")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { card.frame(maxWidth: .infinity).listRowBackground(Color.clear) }
                Section {
                    Toggle("Show where", isOn: $showPlace).accessibilityIdentifier("share-place")
                } footer: {
                    Text("Only the memo, its date, and its theme are shared unless you turn this on. Never the amount.")
                }
                Section {
                    ShareLink(item: image, preview: SharePreview("A memo", image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("share-send")
                }
            }
            .cardForm()
            .navigationTitle("Share this memo")
            .inlineTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .sheetSize()
    }
}
#endif
