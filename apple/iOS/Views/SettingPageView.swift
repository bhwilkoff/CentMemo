#if os(iOS) || os(macOS)
import SwiftUI

/// D8: one Setting's page, every visit there as a thread (the web's #/setting/<name>).
struct SettingPageView: View {
    let name: String
    @Environment(SessionStore.self) private var session
    @State private var entries: [LedgerEntry] = []
    @State private var loading = true
    @State private var error: String?
    /// D8 renames: the person's name for this place (nil: the bank's, cleaned).
    @State private var placeName: String?
    @State private var renaming = false
    @State private var draft = ""
    /// D15: a SettingPlaceModel on iOS 26 (typed loosely for the iOS 18 floor).
    @State private var places: AnyObject? = nil

    @State private var room: CGFloat = 0

    private var shown: String { placeName ?? name }

    private var hasPlace: Bool {
        if #available(iOS 26.0, *), let model = places as? SettingPlaceModel { return model.place != nil || model.guess != nil || model.canSearchNearby }
        return false
    }

    @ViewBuilder private var place: some View {
        if #available(iOS 26.0, *), let model = places as? SettingPlaceModel, hasPlace {
            SettingPlaceSection(model: model, setting: name, shownName: shown, entries: entries)
        }
    }

    private var summary: String {
        let written = entries.filter { $0.memo != nil }.count
        return [entries.count == 1 ? "1 visit" : "\(entries.count) visits",
                entries.count > 1 ? entries.last.map { "since \(LedgerDate.display($0.txnDate))" } : nil,
                written == 0 ? nil : (written == 1 ? "1 memo" : "\(written) memos")]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            HStack(alignment: .top, spacing: 0) {
            List {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    StoreTile(name: shown, category: entries.first?.category ?? "", size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        SettingTitle(name: shown)
                        if !entries.isEmpty {
                            Text(summary).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                                .accessibilityIdentifier("setting-summary")
                        }
                        if placeName != nil {
                            Text("On the statement: \(name)").font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                    }
                }
                .onGround().listRowSeparator(.hidden).columnRowInsets()
                if room < Room.desk { place.onGround().listRowSeparator(.hidden).columnRowInsets() }
                if entries.isEmpty {
                    Text("Nothing at \(name) in your CentMemo.").foregroundStyle(Color.brandTextMuted).onGround()
                } else {
                    // A plain link, never the pane's: this page covers both columns.
                    ForEach(entries) { e in
                        NavigationLink(value: EntryRoute(id: e.id)) { ThreadRow(entry: e, showsPlace: false) }
                            .onGround().listRowSeparator(.hidden).columnRowInsets(vertical: 0)
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxWidth: room >= Room.desk ? Room.measure + PaneEdges.words * 2 : .infinity)
            // W6: the place stands beside its visits when there is room.
            if room >= Room.desk, hasPlace {
                place.padding(.top, Spacing.s4).padding(.trailing, PaneEdges.pane).frame(width: Room.aside + PaneEdges.pane)
            }
            }
            .frame(maxWidth: .infinity)
        }
        .readsRoom($room)
        .grounded()
        .navigationTitle("")
        .inlineTitle()
        .toolbar {
            Button("Rename", systemImage: "pencil") { draft = shown; renaming = true }
                .accessibilityIdentifier("setting-rename")
        }
        .alert("Rename \(name)", isPresented: $renaming) {
            TextField("Name", text: $draft).capitalizesWords()
            Button("Save") { Task { await rename(draft) } }
            if placeName != nil { Button("Use the statement name") { Task { await rename("") } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every visit here takes this name.")
        }
        .task { await load() }
    }

    private func rename(_ new: String) async {
        do {
            try await APIClient.shared.renameSetting(name, to: new)
            placeName = APIClient.shared.settingNames?[name]
            session.didChangeData()
            Haptic.success()
        } catch { self.error = session.handle(error) }
    }

    private func load() async {
        loading = true
        do {
            placeName = (try? await APIClient.shared.loadSettingNames())?[name]
            entries = try await APIClient.shared.atSetting(name).filter { !$0.isSkipped }
            error = nil
            if #available(iOS 26.0, *) {
                let model = (places as? SettingPlaceModel) ?? SettingPlaceModel()
                places = model
                await model.load(setting: name, shownName: shown, entries: entries)
            }
        } catch { self.error = session.handle(error) }
        loading = false
    }
}
#endif
