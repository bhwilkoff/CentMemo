#if os(iOS)
import SwiftUI

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
                    Section("Values") {
                        FlowLayout(spacing: 8) {
                            ForEach(values) { v in
                                Button { toggle(v.id) } label: { ValueChip(name: v.name, isOn: chosen.contains(v.id)) }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(chosen.contains(v.id) ? .isSelected : [])
                            }
                        }
                        HStack {
                            TextField("Add a value", text: $newValue).onSubmit { Task { await addValue() } }
                            Button("Add") { Task { await addValue() } }.disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { writing = false }
                }
            }
        }
        .task { await load() }
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
            entry = try await e
            values = try await v
            memo = entry?.memo?.body ?? ""
            chosen = Set(entry?.memo?.valueIDs ?? [])
            error = nil
        } catch { self.error = session.handle(error) }
        loading = false
    }

    private func addValue() async {
        let name = newValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let v = try await APIClient.shared.addValue(name)
            values.append(v); values.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            chosen.insert(v.id); newValue = ""; error = nil
        } catch {
            self.error = error.localizedDescription.contains("duplicate") ? "You already have that value." : session.handle(error)
        }
    }

    private func save() async {
        error = nil
        if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chosen.isEmpty {
            error = "Write the memo first; values belong to a memo."
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
