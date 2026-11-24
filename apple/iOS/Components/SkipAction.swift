#if os(iOS) || os(macOS)
import SwiftUI

extension View {
    /// Skip (Decision 065): swipe an event away as a detail that stays out of the
    /// Story; a skipped event swipes back. Never a delete, so no confirmation.
    func skipAction(_ e: LedgerEntry, perform: @escaping () async -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Haptic.light()
                Task { await perform() }
            } label: {
                Label(e.isSkipped ? "Bring back" : "Skip", systemImage: e.isSkipped ? "arrow.uturn.backward" : "forward")
            }
            .tint(Color.brandTextMuted)
        }
    }
}
#endif
