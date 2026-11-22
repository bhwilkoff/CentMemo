#if os(iOS)
import SwiftUI
import PhotosUI
import Photos

/// One purchase: what the bank says, then the memo in the person's own words
/// and the values they name. Only the person writes here (Decision 056).
struct EntryDetailView: View {
    let entryID: String
    @Environment(SessionStore.self) private var session
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

    var body: some View {
        LoadState(isLoading: loading, error: entry == nil ? error : nil, retry: load) {
            if let e = entry {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(e.displayMerchant).font(DisplayType.title)
                            MoneyText(minor: e.amountMinor, currency: e.currency, font: TypeRamp.sectionHeader)
                        }
                        LabeledContent("Date", value: LedgerDate.display(e.txnDate))
                        if let posted = e.postedDate, posted != e.txnDate { LabeledContent("Posted", value: LedgerDate.display(posted)) }
                        if !e.category.isEmpty { LabeledContent("Category", value: e.category) }
                        if !e.txnType.isEmpty { LabeledContent("Type", value: e.txnType) }
                        if e.status != "booked" { LabeledContent("Status", value: e.status.capitalized) }
                        if let account = e.accountName { LabeledContent("Account", value: account) }
                        if !e.description.isEmpty, e.description != e.merchant {
                            LabeledContent("Statement") { Text(e.description).font(TypeRamp.caption) }
                        }
                    }
                    Section {
                        TextEditor(text: $memo)
                            .frame(minHeight: 140)
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
                            Text(status).accessibilityIdentifier("memo-status")
                        }
                    }
                    Section("Themes") {
                        FlowLayout(spacing: 8) {
                            ForEach(values) { v in
                                Button { toggle(v.id) } label: { ValueChip(name: v.name, isOn: chosen.contains(v.id)) }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(chosen.contains(v.id) ? .isSelected : [])
                            }
                        }
                        HStack {
                            TextField("Add a theme", text: $newValue).onSubmit { Task { await addValue() } }
                            Button("Add") { Task { await addValue() } }.disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    Section("Photos") {
                        if !photos.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                                ForEach(photos) { a in
                                    AttachedPhoto(ref: a.deviceRef ?? "")
                                        .contextMenu {
                                            Button("Remove from this memo", role: .destructive) { Task { await remove(a) } }
                                        }
                                }
                            }
                            .accessibilityIdentifier("attached-photos")
                        }
                        Button { Task { await openPicker() } } label: {
                            Label("Add a photo", systemImage: "photo.badge.plus")
                        }
                        .accessibilityIdentifier("add-photo")
                    }
                    if let error { Section { Text(error).foregroundStyle(Color.semanticError) } }

                }
            } else {
                ContentUnavailableView("This purchase isn't in your CentMemo.", systemImage: "questionmark")
            }
        }
        .grounded()
        .navigationTitle(entry?.displayMerchant ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        // Save stays reachable while the keyboard is up (found by the iPhone 12 tap
        // tier: the keyboard covered a Save button at the bottom of the form).
        .toolbar {
            if entry != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saving ? "Saving…" : "Save") { writing = false; Task { await save() } }
                        .disabled(saving)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("save-memo")
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { writing = false }
                }
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

    private func toggle(_ id: String) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
        UISelectionFeedbackGenerator().selectionChanged()
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.error = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func remove(_ a: APIClient.Attachment) async {
        do { try await APIClient.shared.removeAttachment(a.id); photos.removeAll { $0.id == a.id } }
        catch { self.error = session.handle(error) }
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
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        saving = true
        do {
            try await APIClient.shared.saveMemo(transactionID: entryID, body: memo, valueIDs: Array(chosen))
            status = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Memo removed." : "Saved."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            session.didChangeData()
        } catch {
            self.error = session.handle(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        saving = false
    }
}
#endif
