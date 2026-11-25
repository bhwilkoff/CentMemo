#if os(iOS) || os(macOS)
import SwiftUI
import PhotosUI
import Photos

/// One purchase: what the bank says, then the memo in the person's own words
/// and the values they name. Only the person writes here (Decision 056).
struct EntryDetailView: View {
    let entryID: String
    @Environment(SessionStore.self) private var session
    @Environment(\.inPane) private var inPane
    @State private var entry: LedgerEntry?
    @State private var values: [LifeValue] = []
    @State private var memo = ""
    @State private var chosen: Set<String> = []
    @State private var newValue = ""
    @State private var status: String?
    @State private var error: String?
    @State private var loading = true
    @State private var saving = false
    @FocusState private var writing: Bool
    @State private var photos: [APIClient.Attachment] = []
    @State private var picked: PhotosPickerItem?
    @State private var picking = false
    @State private var choosingFile = false
    @Environment(\.openURL) private var openURL
    @State private var drawn: CGFloat = 0
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
        // Save stays reachable while the keyboard is up (found by the iPhone 12 tap
        // tier: the keyboard covered a Save button at the bottom of the form).
        .toolbar {
            if entry != nil {
                ToolbarItem(placement: .mainAction) {
                    Button(saving ? "Saving…" : "Save") { writing = false; Task { await save() } }
                        .disabled(saving)
                        .fontWeight(.semibold)
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityIdentifier("save-memo")
                }
                // D12: share a written memo as a card (private by default).
                if let e = entry, let body = e.memo?.body, !body.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Share", systemImage: "square.and.arrow.up") { sharing = true }
                            .accessibilityIdentifier("share-memo")
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Make a link", systemImage: "link") { linking = true }
                            .accessibilityIdentifier("link-memo")
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
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { writing = false }
                }
                #endif
            }
        }
        .sheet(isPresented: $sharing) {
            if let e = entry, let body = e.memo?.body ?? Self.standInMemo {
                ShareMemoSheet(entry: e, memo: body)
            }
        }
        .sheet(isPresented: $linking) {
            if let e = entry, let body = e.memo?.body ?? Self.standInMemo {
                MakeLinkSheet(entry: e, memo: body)
            }
        }
        .task { await load() }
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
            TextEditor(text: $memo)
                .scrollContentBackground(.hidden)  // the card is the page; the Mac drew a white box on it
                .frame(minHeight: room >= Room.desk ? 320 : 160)
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("What do you want to remember?").font(DisplayType.memo)
                            .foregroundStyle(Color.brandTextMuted.opacity(0.7))
                            .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                    }
                }
                .font(DisplayType.memo)
                .accessibilityLabel("Memo")
                .accessibilityIdentifier("memo-editor")
                .focused($writing)
        } header: {
            Text("Memo")
        } footer: {
            // The confirmation sits under the memo, where the person is
            // looking (the iPhone 12 tap tier found it off-screen below).
            if let status {
                HStack(spacing: Spacing.s2) {
                    // The moment a memo is kept: one pencil stroke draws in.
                    if status == "Saved." {
                        PencilStroke().trim(from: 0, to: drawn)
                            .stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 72, height: 8)
                            .accessibilityHidden(true)
                    }
                    Text(status).accessibilityIdentifier("memo-status")
                }
            }
        }
    }

    /// What belongs to the memo: themes, photos, files, the place, the bank's facts.
    @ViewBuilder private func belongings(_ e: LedgerEntry) -> some View {
        Section("Themes") {
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
        loading = true
        do {
            async let e = APIClient.shared.transaction(entryID)
            async let v = APIClient.shared.values()
            async let p = APIClient.shared.attachments(for: entryID)
            entry = try await e
            values = try await v
            photos = try await p
            memo = entry?.memo?.body ?? ""
            chosen = Set(entry?.memo?.valueIDs ?? [])
            if let key = entry?.settingKey { place = (try? await APIClient.shared.loadSettingPlaces())?[key] }
            #if DEBUG
            // DEBUG door APP_START_SHARE=1: the share studio, for captures where nothing can tap (iPad, Duo).
            if ProcessInfo.processInfo.environment["APP_START_SHARE"] == "1", entry?.memo != nil || Self.standInMemo != nil { sharing = true }
            if ProcessInfo.processInfo.environment["APP_START_SHARE"] == "link", entry?.memo != nil || Self.standInMemo != nil { linking = true }
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

    private func save() async {
        error = nil
        if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chosen.isEmpty {
            error = "Write the memo first; themes belong to a memo."
            Haptic.error()
            return
        }
        saving = true
        do {
            try await APIClient.shared.saveMemo(transactionID: entryID, body: memo, valueIDs: Array(chosen))
            status = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Memo removed." : "Saved."
            drawn = 0
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { drawn = 1 }
            Haptic.success()
            session.didChangeData()
        } catch {
            self.error = session.handle(error)
            Haptic.error()
        }
        saving = false
    }
}
/// Inline title on a pushed purchase; in a pane the list keeps the screen's title.
private struct InlineTitle: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.inlineTitle() } else { content }
    }
}
#endif
