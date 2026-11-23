#if os(iOS)
import SwiftUI

/// D8: one Setting's page, every visit there as a thread (the web's #/setting/<name>).
struct SettingPageView: View {
    let name: String
    @Environment(SessionStore.self) private var session
    @State private var entries: [LedgerEntry] = []
    @State private var loading = true
    @State private var error: String?

    private var summary: String {
        let written = entries.filter { $0.memo != nil }.count
        return [entries.count == 1 ? "1 visit" : "\(entries.count) visits",
                entries.count > 1 ? entries.last.map { "since \(LedgerDate.display($0.txnDate))" } : nil,
                written == 0 ? nil : (written == 1 ? "1 memo" : "\(written) memos")]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        LoadState(isLoading: loading && entries.isEmpty, error: error, retry: load) {
            List {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    StoreTile(name: name, category: entries.first?.category ?? "", size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        SettingTitle(name: name)
                        if !entries.isEmpty {
                            Text(summary).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                                .accessibilityIdentifier("setting-summary")
                        }
                    }
                }
                .onGround().listRowSeparator(.hidden).columnRowInsets()
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
        }
        .grounded()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            entries = try await APIClient.shared.atSetting(name).filter { !$0.isSkipped }
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }
}
#endif
