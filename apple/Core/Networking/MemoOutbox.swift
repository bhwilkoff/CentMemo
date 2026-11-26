import Foundation

/// W3 (Decision 069): a memo saves itself. What the person wrote is kept on this device,
/// sealed, before it is sent, and stays until the server has it, so a memo written
/// offline or in a closing app is never lost. Ben, 2026-11-26: "Why not just have it autosave?"
struct MemoDraft: Codable, Sendable, Equatable {
    var body: String
    var valueIDs: [String]

    /// What the server keeps: the words trimmed, the themes in any order.
    func same(as other: MemoDraft) -> Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines) == other.body.trimmingCharacters(in: .whitespacesAndNewlines)
            && Set(valueIDs) == Set(other.valueIDs)
    }
}

extension APIClient {
    private var outboxName: String? {
        guard let who: String = session?.userID else { return nil }
        return who + "/memo-outbox"
    }

    /// Every memo not yet confirmed by the server, by purchase.
    func unsent() -> [String: MemoDraft] {
        guard let name = outboxName, let data = ReadStore.load(name, durable: true) else { return [:] }
        return (try? JSONDecoder().decode([String: MemoDraft].self, from: data)) ?? [:]
    }

    private func writeOutbox(_ all: [String: MemoDraft]) {
        guard let name = outboxName, let who = session?.userID, let data = try? JSONEncoder().encode(all) else { return }
        ReadStore.save(data, as: name, durable: true, if: { Self.signedInID.withLock { $0 } == who })
    }

    func keep(_ draft: MemoDraft, for transactionID: String) {
        var all = unsent()
        guard all[transactionID] != draft else { return }
        all[transactionID] = draft
        writeOutbox(all)
    }

    /// Sends one memo; it leaves the device's keeping only if nothing newer was written meanwhile.
    func send(_ draft: MemoDraft, for transactionID: String) async throws {
        keep(draft, for: transactionID)
        try await saveMemo(transactionID: transactionID, body: draft.body, valueIDs: draft.valueIDs)
        var all = unsent()
        if all[transactionID] == draft { all[transactionID] = nil; writeOutbox(all) }
    }

    /// Whatever was written but not sent, sent now (on opening, and on coming back).
    /// Returns how many reached the server.
    @discardableResult
    func sendUnsent() async -> Int {
        var sent = 0
        for (id, draft) in unsent() {
            do { try await send(draft, for: id); sent += 1 } catch { break }
        }
        return sent
    }
}
