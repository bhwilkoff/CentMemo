#if os(iOS) || os(macOS)
import SwiftUI
import PhotosUI
import Photos
#if os(iOS)
import PencilKit
#endif

/// One purchase: what the bank says, then the memo in the person's own words
/// and the values they name. Only the person writes here (Decision 056).
struct EntryDetailView: View {
    let entryID: String
    @Environment(SessionStore.self) private var session
    @Environment(\.inPane) private var inPane
    @State private var entry: LedgerEntry?
    @State private var values: [LifeValue] = []
    @State private var valuesLoaded = false
    @State private var memo = ""
    @State private var chosen: Set<String> = []
    @State private var newValue = ""
    @State private var error: String?
    @State private var loading = true
    /// W3: nil when the server has the memo; otherwise why it is only on this device.
    @State private var unsent: String?
    @Environment(\.scenePhase) private var phase
    @State private var photos: [APIClient.Attachment] = []
    @State private var picked: PhotosPickerItem?
    @State private var picking = false
    @State private var choosingFile = false
    /// W5: the drawing open on the canvas; `nil` id for a new one.
    @State private var inking: InkEdit?
    @Environment(\.openURL) private var openURL
    @State private var sharing = false
    @State private var linking = false
    @State private var room: CGFloat = 0
    /// D15: the Setting's confirmed place, if the person confirmed one.
    @State private var place: APIClient.SettingPlace?

    var body: some View {
        LoadState(isLoading: loading, error: entry == nil ? error : nil, retry: load) {
            if let e = entry {
                // W3: a desk when there is room, the phone's single page when not.
                if room >= Room.desk {
                    HStack(spacing: 0) {
                        Form { writing(e) }
                            .cardForm()
                            .modifier(PaneMargins(on: true))
                            .frame(maxWidth: Room.measure + PaneEdges.pane * 2)
                        Form { belongings(e) }
                            .cardForm()
                            .modifier(PaneMargins(on: true))
                            .frame(width: Room.aside)
                    }
                    .contentMargins(.top, Spacing.s4, for: .scrollContent)  // both columns start on one line
                    .frame(maxWidth: .infinity)
                } else {
                    Form {
                        writing(e)
                        belongings(e)
                    }
                    .cardForm()
                    .modifier(PaneMargins(on: inPane))
                }
            } else {
                ContentUnavailableView("This event isn't in your CentMemo.", systemImage: "questionmark")
            }
        }
        .readsRoom($room)
        .grounded()
        .navigationTitle(inPane ? "" : (entry?.displayMerchant ?? ""))
        .modifier(InlineTitle(on: !inPane))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if entry != nil {
                // D12: share a written memo as a card (private by default).
                if let e = entry, let body = e.memo?.body, !body.isEmpty {
                    // W6: one Share; a picture or a link is chosen inside it.
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share", systemImage: "square.and.arrow.up") { sharing = true }
                            .accessibilityIdentifier("share-memo")
                    }
                }
                // Skip (Decision 065), also reachable without the list's swipe.
                ToolbarItem(placement: .secondaryAction) {
                    let skipped = entry?.isSkipped == true
                    Button(skipped ? "Bring back" : "Skip", systemImage: skipped ? "arrow.uturn.backward" : "forward") {
                        Task {
                            do { try await APIClient.shared.setSkipped(entryID, !skipped); session.didChangeData(); await load() }
                            catch { self.error = session.handle(error) }
                        }
                    }
                    .accessibilityIdentifier("skip-event")
                }
            }
        }
        .sheet(isPresented: $sharing) {
            if let e = entry, let body = e.memo?.body ?? Self.standInMemo {
                OneShareSheet(start: linking ? .link : .picture) {
                    ShareMemoSheet(entry: e, memo: MemoText.plain(body))
                } page: {
                    MakeLinkSheet(entry: e, memo: MemoText.plain(body))
                }
            }
        }
        .task { await load() }
        #if os(iOS)
        .sheet(item: $inking) { edit in
            InkSheet(load: { await edit.attachment.asyncMap { try? await APIClient.shared.inkDrawing($0) } ?? nil },
                     keep: { d in await keepInk(d, edit.attachment) },
                     words: { found in memo += (memo.isEmpty || memo.hasSuffix("\n") ? "" : "\n") + found })
        }
        #endif
        // W3 (Decision 069): no Save button. A pause in the writing sends it; leaving the
        // page or the app sends it at once. An empty memo is removed only on leaving, so
        // clearing the words to start again never drops the themes on the way.
        .task(id: draft) {
            guard !loading, entry != nil, !isSent(draft) else { return }
            // Kept at once, so a memo emptied or written just before the app closes still counts.
            APIClient.shared.keep(draft, for: entryID)
            guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await send(draft)
        }
        .onDisappear { flush() }
        .onChange(of: phase) { _, now in if now != .active { flush() } }
        // The picker exists only while this sheet is up: created with the shared
        // library it asks for Photos access as soon as it appears, so it must not
        // sit in the form (the iPhone 12 tap tier caught the prompt on scroll).
        // The shared library is what makes it return the asset's identifier, all
        // CentMemo keeps (money-story-design: by reference).
        .sheet(isPresented: $picking) {
            PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) { EmptyView() }
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities(.selectionActions)
                .ignoresSafeArea()
        }
        .onChange(of: picked) { _, item in
            guard let ref = item?.itemIdentifier else { return }
            picked = nil
            picking = false
            Task { await attach(ref) }
        }
    }

    /// What the person writes: the Setting and the memo (D6).
    @ViewBuilder private func writing(_ e: LedgerEntry) -> some View {
        // D6: the Setting and the memo lead; the money is a footnote
        // (Decision 065: memo, Setting; the Chronicle direction).
        Section {
            // D8: the Setting heads the page and opens every visit there.
            NavigationLink(value: SettingRoute(name: e.settingKey)) {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    StoreTile(name: e.displayMerchant, category: e.category, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        SettingTitle(name: e.displayMerchant)
                        HStack(spacing: 0) {
                            Text(LedgerDate.display(e.txnDate) + " · ").foregroundStyle(Color.brandTextMuted)
                            Text("Every visit").foregroundStyle(Color.brandPrimary)
                        }
                        .font(TypeRamp.caption)
                    }
                }
            }
            .accessibilityIdentifier("every-visit")
            .listRowBackground(Color.clear)
            // In a pane the Form's cards stand 16pt off the divider; the header
            // stands with them (Ear Drama iOS-DESIGN §3.6e).
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        Section {
            // W4: styled text, kept as Markdown (MemoText); the format bar rides the keyboard.
            MemoEditor(markdown: $memo, minHeight: room >= Room.desk ? 320 : 160, focused: nil)
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("What do you want to remember?").font(DisplayType.memo)
                            .foregroundStyle(Color.brandTextMuted.opacity(0.7))
                            .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                    }
                }
        } header: {
            Text("Memo")
        } footer: {
            #if DEBUG
            // DEBUG door APP_SHOW_MARKDOWN=1: the memo as the server holds it, for the tap tier (W4).
            if ProcessInfo.processInfo.environment["APP_SHOW_MARKDOWN"] == "1" {
                Text(entry?.memo?.body ?? "").font(.caption.monospaced()).accessibilityIdentifier("memo-markdown")
            }
            #endif
            // Only a failure speaks (W3): the memo is safe here, and not yet sent.
            if let unsent {
                Label(unsent, systemImage: "icloud.slash")
                    .font(TypeRamp.caption).foregroundStyle(Color.brandText)
                    .accessibilityIdentifier("memo-unsent")
            }
        }
        // W5: ink is a memo part, after the words. Drawn on iPhone and iPad; the Mac shows it.
        let inks = photos.filter { $0.kind == "ink" }
        #if os(iOS)
        let canDraw = true
        #else
        let canDraw = false
        #endif
        if !inks.isEmpty || canDraw {
            Section {
                ForEach(inks) { a in
                    if let path = a.storagePath {
                        Button { inking = InkEdit(attachment: a) } label: { InkPicture(path: path) }
                            .buttonStyle(.plain)
                            .disabled(!canDraw)
                            .contextMenu {
                                if canDraw { Button("Draw on it", systemImage: "pencil.tip") { inking = InkEdit(attachment: a) } }
                                Button("Remove from this memo", systemImage: "trash", role: .destructive) { Task { await removeInk(a) } }
                            }
                    }
                }
                #if os(iOS)
                Button { inking = InkEdit(attachment: nil) } label: {
                    Label(inks.isEmpty ? "Draw or write by hand" : "Add a drawing", systemImage: "pencil.tip.crop.circle.badge.plus")
                }
                .accessibilityIdentifier("add-ink")
                #endif
            } header: {
                Text("Drawing")
            }
        }
    }

    /// What belongs to the memo: themes, photos, files, the place, the bank's facts.
    @ViewBuilder private func belongings(_ e: LedgerEntry) -> some View {
        Section("Themes") {
            if values.isEmpty && valuesLoaded {
                StarterThemeChips { s in await addStarter(s) }
            }
            if !values.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(values) { v in
                        Button { toggle(v.id) } label: { ValueChip(name: v.name, isOn: chosen.contains(v.id)) }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(chosen.contains(v.id) ? .isSelected : [])
                    }
                }
            }
            HStack {
                TextField("Add a theme", text: $newValue, prompt: Text("Add a theme")).labelsHidden().onSubmit { Task { await addValue() } }
                Button("Add") { Task { await addValue() } }.disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        Section("Photos") {
            if photos.contains(where: { $0.kind == "photo" }) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(photos.filter { $0.kind == "photo" }) { a in
                        AttachedPhoto(ref: a.deviceRef ?? "")
                            .overlay(alignment: .bottomTrailing) {
                                if a.storagePath != nil {
                                    Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette)
                                        .foregroundStyle(Color.white, Color.brandPrimary).padding(4)
                                        .accessibilityLabel("A copy is kept in CentMemo")
                                }
                            }
                            .contextMenu {
                                if let path = a.storagePath {
                                    Button("Remove the copy in CentMemo", systemImage: "minus.circle") { Task { await dropCopy(a, path) } }
                                } else {
                                    Button("Keep a copy in CentMemo", systemImage: "square.and.arrow.up") { Task { await keepCopy(a) } }
                                }
                                Button("Remove from this memo", role: .destructive) { Task { await remove(a) } }
                            }
                            .accessibilityIdentifier("attached-photo")
                    }
                }
                .accessibilityIdentifier("attached-photos")
            }
            Button { Task { await openPicker() } } label: {
                Label("Add a photo", systemImage: "photo.badge.plus")
            }
            .accessibilityIdentifier("add-photo")
        }
        // Item 10: files (a receipt, a ticket), kept as private copies.
        Section {
            ForEach(photos.filter { $0.kind == "file" }) { a in
                Button { Task { await openFile(a) } } label: {
                    Label(a.caption ?? a.deviceRef ?? "File", systemImage: (a.storagePath ?? "").hasSuffix(".pdf") ? "doc.richtext" : "photo")
                }
                .contextMenu {
                    Button("Remove from this memo", role: .destructive) { Task { await remove(a) } }
                }
                .accessibilityIdentifier("attached-file")
            }
            Button { choosingFile = true } label: { Label("Add a file", systemImage: "doc.badge.plus") }
                .accessibilityIdentifier("add-file")
        } header: {
            Text("Files")
        } footer: {
            Text("Files you add are kept in CentMemo, privately.")
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result { Task { await addFile(url) } }
        }
        if let error { Section { Text(error).foregroundStyle(Color.semanticError) } }
        // D15: where it happened, under the memo (D6: the memo leads).
        if #available(iOS 26.0, *), let place {
            Section {
                PlaceMap(name: place.name, address: place.address, lat: place.lat, lon: place.lon)
                    .accessibilityIdentifier("entry-place")
            }
        }
        // The money and the bank's facts: a footnote, there when wanted.
        Section {
            DisclosureGroup {
                LabeledContent("Date", value: LedgerDate.display(e.txnDate))
                if let posted = e.postedDate, posted != e.txnDate { LabeledContent("Posted", value: LedgerDate.display(posted)) }
                if !e.category.isEmpty { LabeledContent("Category", value: e.category) }
                if !e.txnType.isEmpty { LabeledContent("Type", value: e.txnType) }
                if e.status != "booked" { LabeledContent("Status", value: e.status.capitalized) }
                if let account = e.accountName { LabeledContent("Account", value: account) }
                if !e.description.isEmpty, e.description != e.merchant {
                    LabeledContent("Statement") { Text(e.description).font(TypeRamp.caption) }
                }
            } label: {
                HStack {
                    MoneyText(minor: e.amountMinor, currency: e.currency, font: TypeRamp.caption)
                    Text([e.accountName, e.category.isEmpty ? nil : e.category].compactMap { $0 }.joined(separator: " · "))
                        .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                }
            }
            .accessibilityIdentifier("event-details")
        }
    }

    private func toggle(_ id: String) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
        Haptic.selection()
    }

    /// DEBUG door APP_SHARE_MEMO: words for a share capture on a phone whose account has
    /// no memos. Never saved, and the server publishes only a saved memo.
    private static var standInMemo: String? {
        #if DEBUG
        ProcessInfo.processInfo.environment["APP_SHARE_MEMO"]
        #else
        nil
        #endif
    }

    private func load() async {
        loading = entry == nil
        if entry == nil {
            await APIClient.shared.kept { try await self.read() }
            if entry != nil { loading = false }
        }
        do {
            try await read()
            if let key = entry?.settingKey { place = (try? await APIClient.shared.loadSettingPlaces())?[key] }
            #if DEBUG
            // DEBUG door APP_START_SHARE=1: the share studio, for captures where nothing can tap (iPad, Duo).
            if ProcessInfo.processInfo.environment["APP_START_SHARE"] == "1", entry?.memo != nil || Self.standInMemo != nil { sharing = true }
            if ProcessInfo.processInfo.environment["APP_START_SHARE"] == "link", entry?.memo != nil || Self.standInMemo != nil { linking = true; sharing = true }
            #endif
            #if DEBUG && os(iOS)
            if ProcessInfo.processInfo.environment["APP_ATTACH_SAMPLE_FILE"] == "1", !photos.contains(where: { $0.kind == "file" }) {
                let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200)).pdfData { ctx in
                    ctx.beginPage()
                    ("Sample receipt" as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
                }
                await upload(name: "Sample receipt.pdf", raw: pdf, isPDF: true)
            }
            #endif
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }

    /// The words and themes follow the server only while the person has not changed them.
    private func read() async throws {
        // Looked at before the reads go out: a memo kept here and sent meanwhile is newer
        // than an answer the server gave before it arrived.
        let pending = APIClient.shared.unsent()[entryID]
        async let e = APIClient.shared.transaction(entryID)
        async let v = APIClient.shared.values()
        async let p = APIClient.shared.attachments(for: entryID)
        let fresh = try await e, themes = try await v, attached = try await p
        let was = entry?.memo
        let untouched = memo == (was?.body ?? "") && chosen == Set(was?.valueIDs ?? [])
        values = themes
        valuesLoaded = true
        photos = attached
        entry = fresh
        if untouched {
            // A memo written here and not yet sent is newer than the server's.
            if let kept = pending {
                memo = kept.body; chosen = Set(kept.valueIDs)
            } else {
                memo = fresh?.memo?.body ?? ""
                chosen = Set(fresh?.memo?.valueIDs ?? [])
            }
        }
    }

    private var draft: MemoDraft { MemoDraft(body: memo, valueIDs: chosen.sorted()) }

    /// The server already holds these words and themes.
    private func isSent(_ d: MemoDraft) -> Bool {
        d.same(as: MemoDraft(body: entry?.memo?.body ?? "", valueIDs: entry?.memo?.valueIDs ?? []))
    }

    /// Leaving the page or the app: whatever differs goes now, an empty memo included.
    private func flush() {
        guard !loading, entry != nil, !isSent(draft) else { return }
        let d = draft
        APIClient.shared.keep(d, for: entryID)
        Task { await send(d, leaving: true) }
    }

    /// Asks for Photos access when the person chooses to add one, with the reason in
    /// NSPhotoLibraryUsageDescription. Declining still lets them attach by reference.
    private func openPicker() async {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        picking = true
    }

    private func attach(_ ref: String) async {
        do {
            photos.append(try await APIClient.shared.attachPhoto(transactionID: entryID, deviceRef: ref))
            Haptic.success()
        } catch {
            self.error = session.handle(error)
            Haptic.error()
        }
    }

    private func remove(_ a: APIClient.Attachment) async {
        do { try await APIClient.shared.removeAttachment(a.id, copy: a.storagePath); photos.removeAll { $0.id == a.id } }
        catch { self.error = session.handle(error) }
    }

    /// Item 10: a file the person chose; an image is re-encoded (no metadata).
    private func addFile(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { self.error = "CentMemo couldn't open that file."; return }
        await upload(name: url.lastPathComponent, raw: raw, isPDF: url.pathExtension.lowercased() == "pdf")
    }

    private func upload(name: String, raw: Data, isPDF: Bool) async {
        let data: Data?
        if isPDF { data = raw } else { data = PlatformImage(data: raw).flatMap(Pixels.jpeg) }
        guard let data, data.count <= 5_000_000 else {
            self.error = "That file is too large to keep (5 MB at most)."
            Haptic.error()
            return
        }
        do {
            let a = try await APIClient.shared.attachFile(transactionID: entryID, name: name, data: data, isPDF: isPDF)
            photos.append(a)
            Haptic.success()
        } catch { self.error = session.handle(error); Haptic.error() }
    }

    private func openFile(_ a: APIClient.Attachment) async {
        guard let path = a.storagePath else { return }
        do { openURL(try await APIClient.shared.copyURL(path)) } catch { self.error = session.handle(error) }
    }

    /// Item 10: the person chose to keep a copy, so the web can show it too.
    private func keepCopy(_ a: APIClient.Attachment) async {
        guard let ref = a.deviceRef, let jpeg = await AttachedPhoto.copyForUpload(ref: ref) else {
            let allowed = [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite))
            self.error = allowed ? "CentMemo couldn't read that photo from your library."
                : "To keep a copy, allow CentMemo to see your photos in Settings, then try again."
            Haptic.error()
            return
        }
        do {
            let path = try await APIClient.shared.keepCopy(attachmentID: a.id, jpeg: jpeg)
            if let i = photos.firstIndex(where: { $0.id == a.id }) { photos[i].storagePath = path }
            Haptic.success()
        } catch { self.error = session.handle(error); Haptic.error() }
    }

    private func dropCopy(_ a: APIClient.Attachment, _ path: String) async {
        do {
            try await APIClient.shared.removeCopy(attachmentID: a.id, path: path)
            if let i = photos.firstIndex(where: { $0.id == a.id }) { photos[i].storagePath = nil }
            Haptic.success()
        } catch { self.error = session.handle(error) }
    }

    #if os(iOS)
    private func keepInk(_ d: PKDrawing, _ existing: APIClient.Attachment?) async -> Bool {
        guard let png = InkRender.png(d) else { return false }
        do {
            let a = try await APIClient.shared.saveInk(transactionID: entryID, existing: existing, drawing: d.dataRepresentation(), png: png)
            if let i = photos.firstIndex(where: { $0.id == a.id }) {
                photos[i] = a
                // Same path, new picture: dropped and put back so it loads again.
                photos.remove(at: i); try? await Task.sleep(for: .milliseconds(50)); photos.insert(a, at: i)
            } else { photos.append(a) }
            Haptic.success()
            return true
        } catch { self.error = session.handle(error); Haptic.error(); return false }
    }
    #endif

    private func removeInk(_ a: APIClient.Attachment) async {
        do { try await APIClient.shared.removeInk(a); photos.removeAll { $0.id == a.id } }
        catch { self.error = session.handle(error) }
    }

    private func addStarter(_ s: Themes.Starter) async {
        do {
            let v = try await APIClient.shared.addValue(s.name)
            values.append(v); values.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            chosen.insert(v.id); error = nil
            session.didChangeData()
            Haptic.success()
        } catch { self.error = session.handle(error) }
    }

    private func addValue() async {
        let name = newValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let v = try await APIClient.shared.addValue(name)
            values.append(v); values.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            chosen.insert(v.id); newValue = ""; error = nil
        } catch {
            self.error = error.localizedDescription.contains("duplicate") ? "You already have that theme." : session.handle(error)
        }
    }

    private func send(_ d: MemoDraft, leaving: Bool = false) async {
        let wasEmpty = (entry?.memo?.body ?? "").isEmpty, isEmpty = d.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let themesChanged = d.valueIDs != (entry?.memo?.valueIDs ?? []).sorted()
        do {
            try await APIClient.shared.send(d, for: entryID)
            unsent = nil
            // Share and Make a link read the saved memo, not the one this page opened with.
            if let fresh = try? await APIClient.shared.transaction(entryID) { entry = fresh }
            // The lists follow when a memo appears or goes, its themes change, or the page closes.
            if leaving || wasEmpty != isEmpty || themesChanged { session.didChangeData() }
        } catch {
            #if os(macOS)
            unsent = "Not sent yet. It's kept on this Mac."
            #else
            unsent = "Not sent yet. It's kept on this \(UIDevice.current.model)."
            #endif
        }
    }
}
/// Inline title on a pushed purchase; in a pane the list keeps the screen's title.
private struct InlineTitle: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.inlineTitle() } else { content }
    }
}
/// W5: which drawing is open on the canvas, and its strokes once they arrive.
struct InkEdit: Identifiable {
    let id = UUID()
    let attachment: APIClient.Attachment?
}

extension Optional {
    func asyncMap<T>(_ f: (Wrapped) async -> T) async -> T? {
        guard let self else { return nil }
        return await f(self)
    }
}
#endif
