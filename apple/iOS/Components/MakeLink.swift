#if os(iOS) || os(macOS)
import SwiftUI

/// DESIGN S7: every choice is the writer's, beside the reader's page where there is
/// room, under it on a phone.
struct MakeLinkSheet: View {
    @State var draft: StoryLinkDraft
    @State private var made: (url: URL, of: StoryLinkDraft)?
    @State private var making = false
    @State private var copied = false
    @State private var error: String?
    @State private var room: CGFloat = 0
    @State private var tall: CGFloat = 0
    /// The field being typed in, by its identifier.
    @FocusState private var field: String?
    private var typing: Bool { field != nil }
    @Environment(\.verticalSizeClass) private var height
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    init(entry: LedgerEntry, memo: String) {
        var theme: StoryLinkDraft.Theme?
        if let id = entry.memo?.valueIDs.first, let name = entry.memo?.valueNames.first { theme = .init(id: id, name: name, color: Themes.colorKey(name)) }
        _draft = State(initialValue: StoryLinkDraft(kind: .memo, theme: theme, items: [Self.item(entry, memo)]))
    }
    init(theme: LifeValue, entries: [LedgerEntry]) {
        let items = entries.prefix(100).compactMap { e in e.memo.flatMap { $0.body.isEmpty ? nil : Self.item(e, $0.body) } }
        _draft = State(initialValue: StoryLinkDraft(kind: .theme, theme: .init(id: theme.id, name: theme.name, color: Themes.colorKey(theme.name)), items: items))
    }
    private static func item(_ e: LedgerEntry, _ memo: String) -> StoryLinkDraft.Item {
        .init(id: e.id, memo: memo, shown: e.displayMerchant, shownWhen: LedgerDate.display(e.txnDate))
    }

    /// The page as it stands has its link already; another press would make a twin.
    private var isMade: Bool { made?.of == draft }

    var body: some View {
        NavigationStack {
            Group {
                if room >= 760 || height == .compact {
                    HStack(spacing: 0) {
                        StoryPagePreview(draft: draft)
                        Divider()
                        form.frame(width: min(380, room * 0.5))
                    }
                } else {
                    VStack(spacing: 0) {
                        StoryPagePreview(draft: draft).frame(height: typing ? 150 : max(240, tall * 0.42))
                        Divider()
                        form
                    }
                }
            }
            .readsRoom($room)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if !typing { tall = $0 } }
            .grounded()
            .navigationTitle(draft.kind == .theme ? "Link to this theme" : "Link to this memo")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let made, isMade {
                        ShareLink(item: made.url) { Label("Share", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("link-send")
                    } else {
                        Button(making ? "Making…" : "Make") { Task { await make() } }
                            .disabled(making || draft.problem != nil)
                            .accessibilityIdentifier("link-make")
                    }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { field = nil }
                }
                #endif
            }
        }
        .studioSize()
        .task {
            // Only what is not Apple's to publish may be filled in; on failure they stay empty.
            if let wallet = try? await APIClient.shared.walletIDs(among: draft.items.map(\.id)) { draft.fill(wallet: wallet) }
        }
    }

    /// Kept in view: the field being typed in (the page above it shrinks as the keyboard
    /// comes), and the link once it is made.
    private var form: some View {
        ScrollViewReader { reader in
            Form { choices }
                .cardForm()
                .onChange(of: field) { _, f in
                    guard let f else { return }
                    Task { try? await Task.sleep(for: .milliseconds(450)); withAnimation { reader.scrollTo(f, anchor: .center) } }
                }
                .onChange(of: made?.url) { _, u in
                    guard u != nil else { return }
                    Task { try? await Task.sleep(for: .milliseconds(450)); withAnimation { reader.scrollTo("made", anchor: .center) } }
                }
        }
    }

    /// Always labeled: a filled field must still say what it is.
    private func line(_ label: String, _ id: String, _ text: Binding<String>, hint: String, max: Int) -> some View {
        LabeledContent(label) {
            TextField(label, text: text, prompt: Text(hint)).labelsHidden()
                .multilineTextAlignment(.trailing)
                .focused($field, equals: id)
                .onChange(of: text.wrappedValue) { _, v in if v.count > max { text.wrappedValue = String(v.prefix(max)) } }
                .accessibilityIdentifier(id)
        }
        .id(id)
    }

    @ViewBuilder private var choices: some View {
        if let made {
            Section {
                Text(made.url.absoluteString).font(TypeRamp.caption).textSelection(.enabled).id("made")
                    .accessibilityIdentifier("link-url")
                Button(copied ? "Copied" : "Copy link") { Clipboard.copy(made.url.absoluteString); copied = true; Haptic.selection() }
            } header: {
                Text("Your link is ready")
            } footer: {
                if !isMade { Text("This link keeps the page as it was when you made it. Make another for your changes.") }
            }
        }
        if let error { Section { Text(error).foregroundStyle(Color.semanticError) } }
        Section {
            ForEach($draft.items) { $m in
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    if draft.kind == .theme {
                        Toggle(isOn: $m.on) {
                            Text("\(m.shown), \(m.shownWhen)").font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                    }
                    if m.on { ShareWords(words: m.words, mark: $m.mark, prefix: draft.kind == .theme ? m.id : nil) }
                }
                if m.on {
                    line("Where", "link-place-\(m.id)", $m.place, hint: "In your words", max: 80)
                    line("When", "link-when-\(m.id)", $m.when, hint: "A date, a season, or nothing", max: 60)
                }
            }
        } header: {
            Text("Mark the words that matter")
        } footer: {
            if draft.items.contains(where: \.wallet) {
                Text("For Apple Card purchases, Where and When start empty. Apple’s rules don’t let CentMemo publish the store or the date, so you write them.")
            }
        }
        Section("Pencil") {
            Picker("Pencil", selection: $draft.pencil) { ForEach(StoryLinkDraft.Pencil.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
        }
        Section("Color") {
            Picker("Color", selection: $draft.paper) { ForEach(StoryLinkDraft.Paper.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
        }
        if draft.kind == .memo {
            Section("What leads") {
                Picker("What leads", selection: $draft.lead) {
                    ForEach(StoryLinkDraft.Lead.allCases.filter { $0 != .theme || draft.theme != nil }, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }
        } else {
            Section("Parts of the page") {
                Toggle("Cover", isOn: $draft.cover)
                Toggle("Lines", isOn: $draft.lines)
                Toggle("Each memory", isOn: $draft.mems)
            }
        }
        Section("Show") {
            Toggle("Where", isOn: $draft.showPlace)
            Toggle("When", isOn: $draft.showWhen)
            if draft.kind == .memo, draft.theme != nil { Toggle("Theme", isOn: $draft.showTheme) }
        }
        Section {
            line("Shared by", "link-from", $draft.sharedBy, hint: "Your name, or nothing", max: 60)
        } footer: {
            Text(draft.problem ?? "Anyone with the link can read this page. It isn’t listed anywhere, and you can turn it off in Settings.")
        }
    }

    private func make() async {
        field = nil
        making = true
        let page = draft
        do {
            made = (StoryLink.url(try await APIClient.shared.makeShare(page)), page)
            copied = false; error = nil
            Haptic.success()
        } catch { self.error = session.handle(error); Haptic.error() }
        making = false
    }
}

/// Settings: every link the person made, each turned off at once.
struct YourLinksSection: View {
    @Environment(SessionStore.self) private var session
    @State private var links: [StoryLink]?
    @State private var off: Set<String> = []
    @State private var error: String?

    var body: some View {
        Section {
            if let links {
                if links.isEmpty { Text("None. Make one from a memo or a theme.").foregroundStyle(Color.brandTextMuted) }
                ForEach(links) { l in
                    HStack(spacing: Spacing.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            if off.contains(l.code) { Text(l.title).lineLimit(2).foregroundStyle(Color.brandTextMuted) }
                            else { Link(destination: l.url) { Text(l.title).lineLimit(2).multilineTextAlignment(.leading) } }
                            Text(off.contains(l.code) ? "Off" : "Made \(LedgerDate.display(String(l.createdAt.prefix(10))))")
                                .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                        }
                        Spacer()
                        if !off.contains(l.code) {
                            Button("Turn off") { Task { await turnOff(l) } }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("link-off-\(l.code)")
                        }
                    }
                }
            } else if error == nil {
                ProgressView()
            }
            if let error {
                Text(error).foregroundStyle(Color.semanticError)
                Button("Try again") { Task { await load() } }
            }
        } header: {
            Text("Your links")
        }
        .task { await load() }
    }

    private func load() async {
        error = nil
        do { links = try await APIClient.shared.shares() } catch { self.error = session.handle(error) }
    }
    private func turnOff(_ l: StoryLink) async {
        do { try await APIClient.shared.turnOffShare(l.code); off.insert(l.code); error = nil; Haptic.success() }
        catch { self.error = session.handle(error); Haptic.error() }
    }
}
#endif
