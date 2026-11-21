#if os(iOS)
import SwiftUI

/// Signed out: what CentMemo is and the way in. Signed in: four tabs, one
/// navigation stack each, and ONE shared destination registry (apple.md).
struct ContentView_iOS: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppStore.self) private var store

    var body: some View {
        if session.isSignedIn {
            @Bindable var store = store
            TabView(selection: Binding(get: { store.selectedTab ?? "unexamined" }, set: { store.selectedTab = $0 })) {
                Tab("Unexamined", systemImage: "tray", value: "unexamined") {
                    // The inbox (deep links, test doors) pushes onto this stack.
                    NavigationStack(path: $store.navigationPath) { destinations { UnexaminedView() } }
                }
                Tab("Ledger", systemImage: "list.bullet", value: "ledger") { stack { LedgerView() } }
                Tab("Story", systemImage: "book", value: "story") { stack { StoryView() } }
                Tab("Settings", systemImage: "gearshape", value: "settings") { stack { SettingsView() } }
            }
            .tint(Color.brandPrimary)
        } else {
            SignInView()
        }
    }

    private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack { destinations(content) }
    }

    /// The one destination registry every stack applies.
    private func destinations<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .navigationDestination(for: EntryRoute.self) { EntryDetailView(entryID: $0.id) }
            // Inbox items arrive as bare ids (AppStore lives in Core and can't name EntryRoute).
            .navigationDestination(for: String.self) { EntryDetailView(entryID: $0) }
    }
}

/// Every push to a purchase goes through this one route type.
struct EntryRoute: Hashable { let id: String }
#endif
