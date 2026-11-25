#if os(macOS)
import SwiftUI

/// The Mac shell (macos-platform-patterns rules 1-2): a sidebar of the three
/// sections, the section's list, and the purchase being written. Settings lives
/// in the app menu. The lists and the purchase page are the phone's own views;
/// the window, the menus, and the keys are the Mac's.
struct ContentView_macOS: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppStore.self) private var store
    @State private var pane = PaneSelection()
    @State private var story = StoryModel()

    private var section: Binding<MacSection?> {
        Binding(get: { store.selectedTab.flatMap(MacSection.init(rawValue:)) ?? .unexamined },
                set: { if let s = $0 { store.selectedTab = s.rawValue } })
    }

    var body: some View {
        content.onChange(of: session.isSignedIn) { _, signedIn in
            if !signedIn { pane.route = nil; story = StoryModel() }
        }
    }

    @ViewBuilder private var content: some View {
        if session.isSignedIn {
            @Bindable var store = store
            NavigationSplitView {
                List(MacSection.allCases, selection: section) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
            } content: {
                list
                    .navigationSplitViewColumnWidth(min: 340, ideal: 440, max: 520)
            } detail: {
                NavigationStack(path: $store.navigationPath) {
                    Group {
                        if let r = pane.route {
                            EntryDetailView(entryID: r.id).id(r.id)
                                .toolbar { if section.wrappedValue == .story { backToStory } }
                        } else if section.wrappedValue == .story {
                            StoryReading(model: story).grounded()
                        } else {
                            ContentUnavailableView("Choose a purchase", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity, maxHeight: .infinity).grounded()
                        }
                    }
                    .environment(\.inPane, true)
                    .navigationDestination(for: EntryRoute.self) { EntryDetailView(entryID: $0.id) }
                    .navigationDestination(for: String.self) { EntryDetailView(entryID: $0) }
                    .navigationDestination(for: SettingRoute.self) { SettingPageView(name: $0.name) }
                }
            }
            // The shared links and lists read width: a Mac window is always regular.
            .environment(\.horizontalSizeClass, .regular)
            .environment(pane)
            .tint(Color.brandPrimary)
            .task { await session.loadGround() }
            .onChange(of: pane.route) { store.navigationPath = NavigationPath() }
            .onChange(of: store.openedItem, initial: true) { _, id in
                if let id { pane.route = EntryRoute(id: id) }
            }
            // Each section opens its own first purchase.
            .onChange(of: store.selectedTab) { pane.route = nil }
        } else {
            SignInView()
        }
    }

    @ViewBuilder private var list: some View {
        switch section.wrappedValue ?? .unexamined {
        case .unexamined: UnexaminedView()
        case .ledger: LedgerView()
        case .story:
            List { StoryShelf(model: story) }.listStyle(.plain).grounded()
                .navigationTitle("Story")
                .modifier(StoryChrome(model: story))
        }
    }

    /// The Story fills the detail column; a memo opened from it comes back to it.
    private var backToStory: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Back to the Story", systemImage: "chevron.left") { pane.route = nil }
                .keyboardShortcut("[", modifiers: .command)
        }
    }
}

enum MacSection: String, CaseIterable, Identifiable {
    case unexamined, ledger, story
    var id: Self { self }
    var title: String {
        switch self { case .unexamined: "Unexamined"; case .ledger: "Narrative"; case .story: "Story" }
    }
    var symbol: String {
        switch self { case .unexamined: "tray"; case .ledger: "list.bullet"; case .story: "book" }
    }
}

/// The menu bar: the sections on ⌘1 to ⌘3, and Reload (⌘R), the Mac's pull to refresh.
/// There is no File ▸ New.
struct MacCommands: Commands {
    let store: AppStore
    let session: SessionStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(before: .sidebar) {
            ForEach(Array(MacSection.allCases.enumerated()), id: \.element) { i, s in
                Button(s.title) { store.selectedTab = s.rawValue }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            }
            Divider()
            Button("Reload") { session.didChangeData() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!session.isSignedIn)
            Divider()
        }
    }
}
#endif
