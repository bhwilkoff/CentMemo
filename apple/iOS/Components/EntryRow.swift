#if os(iOS)
import SwiftUI

/// One purchase in a list: merchant, date and category, amount; the first
/// lines of the memo when there is one.
struct EntryRow: View {
    let entry: LedgerEntry
    var showMemo = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayMerchant).font(TypeRamp.bodyStrong)
                Text(subtitle).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                if showMemo, let memo = entry.memo {
                    Text(memo.body).font(TypeRamp.caption).lineLimit(2).padding(.top, 2)
                }
            }
            Spacer(minLength: Spacing.s2)
            MoneyText(minor: entry.amountMinor, currency: entry.currency)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [LedgerDate.display(entry.txnDate), entry.category.isEmpty ? nil : entry.category,
         entry.status == "pending" ? "Pending" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Amounts in tabular figures; credits in the success color, spending never red.
struct MoneyText: View {
    let minor: Int
    var currency = "USD"
    var font: Font = TypeRamp.tabular

    var body: some View {
        Text(Money.format(minor, currency: currency))
            .font(font).monospacedDigit()
            .foregroundStyle(minor > 0 ? Color.semanticSuccess : Color.brandText)
    }
}

/// Chips that wrap onto new lines (SwiftUI has no flow layout of its own).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, frame) in rows(bounds.width, subviews).frames.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                              proposal: ProposedViewSize(frame.size))
        }
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = [], x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, CGSize(width: maxX, height: y + rowHeight))
    }
}

/// Loading, empty, and error states shared by every list (universal-feature-states).
struct LoadState<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let retry: () async -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let error {
            ContentUnavailableView {
                Label("Couldn't load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try again") { Task { await retry() } }
            }
        } else if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content()
        }
    }
}
#endif
