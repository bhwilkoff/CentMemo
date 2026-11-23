import Foundation

/// The one client every view goes through (AGENTS.md hard rule), the Swift twin
/// of js/api.js. Talks to Supabase's REST endpoints directly with URLSession
/// (no third-party packages). Row-level security does the scoping.
/// Money stays integer minor units end to end (Decision 057).
///
/// The JWT is refreshed before every call that is about to expire, and once
/// more on a 401 (Decision 011).
final class APIClient {
    static let shared = APIClient()

    static let projectURL = URL(string: "https://qucsmmazfalbyduxlavl.supabase.co")!
    /// Publishable key: safe in the app; RLS is the guard.
    static let publishableKey = "sb_publishable_XuubuEBTUKXkzttN2MUdzw_Aq7-q6YT"
    /// The connector's public address (workers/mcp-proxy on Cloudflare); the old Supabase address still works.
    static let mcpURL = "https://mcp.centmemo.com"

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Double
        var userID: String
        var email: String?
    }

    enum APIError: Error, LocalizedError {
        case server(String), signedOut, decoding(String)
        var errorDescription: String? {
            switch self {
            case .server(let m): m
            case .signedOut: "You're signed out. Sign in again."
            case .decoding(let m): "CentMemo couldn't read the answer: \(m)"
            }
        }
    }

    private(set) var session: Session? {
        didSet {
            if let session, let data = try? JSONEncoder().encode(session) { Keychain.save(data, account: "session") }
            else { Keychain.delete(account: "session") }
        }
    }

    private init() {
        session = Keychain.load(account: "session").flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
    }

    var isSignedIn: Bool { session != nil }
    var email: String? { session?.email }

    // MARK: - Auth

    /// Sign in with Apple: the identity token Apple signed, exchanged for a
    /// CentMemo session. `nonce` is the raw value whose SHA-256 went to Apple.
    func signInWithApple(idToken: String, nonce: String) async throws {
        struct Body: Encodable { let provider = "apple"; let id_token: String; let nonce: String }
        let data = try await raw("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                 method: "POST", body: Body(id_token: idToken, nonce: nonce), authed: false)
        try adoptAuthResponse(data)
    }

    #if DEBUG
    /// DEBUG only: the synthetic test accounts sign in with a password so the
    /// simulator harness can reach signed-in screens (APP_TEST_EMAIL/PASSWORD).
    func signInForTesting(email: String, password: String) async throws {
        let data = try await raw("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "password")],
                                 method: "POST", body: ["email": email, "password": password], authed: false)
        try adoptAuthResponse(data)
    }
    #endif

    func signOut() async {
        _ = try? await raw("auth/v1/logout", method: "POST", body: [String: String](), authed: true)
        session = nil
    }

    /// In-app account deletion (Decision 035): every row cascades.
    func deleteAccount() async throws {
        _ = try await raw("rest/v1/rpc/delete_my_account", method: "POST", body: [String: String]())
        session = nil
    }

    private func refreshIfNeeded(force: Bool = false) async throws {
        guard let s = session else { throw APIError.signedOut }
        guard force || s.expiresAt < Date().timeIntervalSince1970 + 60 else { return }
        do {
            let data = try await raw("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                     method: "POST", body: ["refresh_token": s.refreshToken], authed: false)
            try adoptAuthResponse(data)
        } catch {
            session = nil
            throw APIError.signedOut
        }
    }

    private func adoptAuthResponse(_ data: Data) throws {
        struct AuthResponse: Decodable {
            let access_token: String, refresh_token: String, expires_in: Double
            let user: User
            struct User: Decodable { let id: String; let email: String? }
        }
        guard let r = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            throw APIError.decoding("sign-in response")
        }
        session = Session(accessToken: r.access_token, refreshToken: r.refresh_token,
                          expiresAt: Date().timeIntervalSince1970 + r.expires_in, userID: r.user.id, email: r.user.email)
    }

    // MARK: - Transport

    @discardableResult
    private func raw(_ path: String, query: [URLQueryItem] = [], method: String = "GET",
                     body: (any Encodable)? = nil, prefer: String? = nil, authed: Bool = true,
                     retried: Bool = false) async throws -> Data {
        if authed { try await refreshIfNeeded() }
        var comps = URLComponents(url: Self.projectURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed, let token = session?.accessToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        #if DEBUG
        // DEBUG door: APP_FAIL_NETWORK=offline|unreachable fails data requests
        // (sign-in still works), so the error state can be seen on a device.
        if path.hasPrefix("rest/v1"), let fail = ProcessInfo.processInfo.environment["APP_FAIL_NETWORK"] {
            throw URLError(fail == "offline" ? .notConnectedToInternet : .cannotConnectToHost)
        }
        #endif
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401, authed, !retried {
            try await refreshIfNeeded(force: true)
            return try await raw(path, query: query, method: method, body: body, prefer: prefer, authed: authed, retried: true)
        }
        guard (200..<300).contains(code) else { throw APIError.server(Self.message(from: data, code: code)) }
        return data
    }

    private static func message(from data: Data, code: Int) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["msg", "message", "error_description", "error"] {
                if let m = obj[key] as? String { return m }
            }
        }
        return "The server answered \(code)."
    }

    private func rest<T: Decodable>(_ table: String, _ query: [URLQueryItem]) async throws -> T {
        let data = try await raw("rest/v1/" + table, query: query)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    // MARK: - Reading

    private static let txnColumns = "id,account_id,txn_date,posted_date,amount_minor,currency,description,merchant,category,txn_type,status,skipped_at"

    func unexamined(limit: Int = 200) async throws -> [LedgerEntry] {
        try await rest("unexamined_transactions", [.init(name: "select", value: Self.txnColumns),
                                                   .init(name: "order", value: "txn_date.desc"),
                                                   .init(name: "limit", value: String(limit))])
    }

    /// D7: what to write about, chosen in the database by readable rules (memo_suggestions).
    struct Suggestion: Decodable, Hashable, Sendable {
        let kind: String
        let transactionID: String
        let memoBody: String?
        /// What kind of purchase it was (a meal, a trip...), so the question fits it.
        var moment: String? = nil
        enum CodingKeys: String, CodingKey { case kind, transactionID = "transaction_id", memoBody = "memo_body", moment }
    }

    func suggestions() async throws -> [Suggestion] {
        let data = try await raw("rest/v1/rpc/memo_suggestions", method: "POST", body: [String: String]())
        var seen = Set<String>()
        return try JSONDecoder().decode([Suggestion].self, from: data).filter { seen.insert($0.transactionID).inserted }
    }

    /// D12: how many memos each theme collects (value id -> count).
    func themeCounts() async throws -> [String: Int] {
        struct Row: Decodable { let value_id: String }
        let rows: [Row] = try await rest("memo_values", [.init(name: "select", value: "value_id"), .init(name: "limit", value: "10000")])
        return rows.reduce(into: [:]) { $0[$1.value_id, default: 0] += 1 }
    }

    func hasAnyTransactions() async throws -> Bool {
        let rows: [[String: String]] = try await rest("transactions", [.init(name: "select", value: "id"), .init(name: "limit", value: "1")])
        return !rows.isEmpty
    }

    func latestMonth() async throws -> String? {
        let rows: [[String: String]] = try await rest("transactions", [.init(name: "select", value: "txn_date"),
                                                                      .init(name: "order", value: "txn_date.desc"),
                                                                      .init(name: "limit", value: "1")])
        return rows.first?["txn_date"].map { String($0.prefix(7)) }
    }

    func month(_ ym: String) async throws -> [LedgerEntry] {
        try await rest("transactions", [.init(name: "select", value: Self.txnColumns + ",memos(body,memo_values(value_id,life_values(name)))"),
                                        .init(name: "txn_date", value: "gte.\(ym)-01"),
                                        .init(name: "txn_date", value: "lte.\(LedgerDate.lastDay(ym))"),
                                        .init(name: "order", value: "txn_date.desc"),
                                        .init(name: "limit", value: "2000")])
    }

    /// D8: every event at one Setting (as the web's atSetting): the pattern finds each
    /// raw descriptor the name came from; only exact cleaned matches are kept.
    func atSetting(_ name: String) async throws -> [LedgerEntry] {
        let p = Money.settingPattern(name)
        guard !p.isEmpty else { return [] }
        let rows: [LedgerEntry] = try await rest("transactions", [
            .init(name: "select", value: Self.txnColumns + ",memos(body,memo_values(value_id,life_values(name)))"),
            .init(name: "or", value: "(merchant.ilike.\(p),description.ilike.\(p))"),
            .init(name: "order", value: "txn_date.desc"), .init(name: "limit", value: "1000")])
        return rows.filter { $0.displayMerchant == name }
    }

    func transaction(_ id: String) async throws -> LedgerEntry? {
        let rows: [LedgerEntry] = try await rest("transactions", [
            .init(name: "select", value: Self.txnColumns + ",accounts(display_name),memos(body,memo_values(value_id,life_values(name)))"),
            .init(name: "id", value: "eq.\(id)"), .init(name: "limit", value: "1")])
        return rows.first
    }

    enum StoryScope: Hashable { case month(String), value(String) }

    func stories(_ scope: StoryScope) async throws -> [LedgerEntry] {
        var q: [URLQueryItem] = [.init(name: "select", value: Self.txnColumns + ",memos!inner(body,memo_values(value_id,life_values(name)))"),
                                 .init(name: "order", value: "txn_date.asc"), .init(name: "limit", value: "1000")]
        switch scope {
        case .month(let ym):
            q += [.init(name: "txn_date", value: "gte.\(ym)-01"), .init(name: "txn_date", value: "lte.\(LedgerDate.lastDay(ym))")]
        case .value(let valueID):
            struct Link: Decodable { let transaction_id: String }
            let links: [Link] = try await rest("memo_values", [.init(name: "select", value: "transaction_id"),
                                                               .init(name: "value_id", value: "eq.\(valueID)")])
            if links.isEmpty { return [] }
            q.append(.init(name: "id", value: "in.(\(links.map(\.transaction_id).joined(separator: ",")))"))
        }
        return try await rest("transactions", q)
    }

    // MARK: - The person's ground (Decision 059)

    func ground() async throws -> Ground {
        struct Row: Decodable { let ground: String }
        let rows: [Row] = try await rest("profiles", [.init(name: "select", value: "ground"), .init(name: "limit", value: "1")])
        return rows.first.flatMap { Ground(rawValue: $0.ground) } ?? .aqua
    }

    func setGround(_ g: Ground) async throws {
        try await raw("rest/v1/profiles", query: [.init(name: "on_conflict", value: "user_id")], method: "POST",
                      body: ["ground": g.rawValue], prefer: "resolution=merge-duplicates")
    }

    // MARK: - Values the person names

    func values() async throws -> [LifeValue] {
        try await rest("life_values", [.init(name: "select", value: "id,name"), .init(name: "order", value: "name")])
    }

    func addValue(_ name: String) async throws -> LifeValue {
        let data = try await raw("rest/v1/life_values", query: [.init(name: "select", value: "id,name")], method: "POST",
                                 body: ["name": name.trimmingCharacters(in: .whitespaces)], prefer: "return=representation")
        guard let v = try JSONDecoder().decode([LifeValue].self, from: data).first else { throw APIError.decoding("new value") }
        return v
    }

    /// Skip (Decision 065): the event leaves the Narrative and Unexamined as a
    /// detail; false brings it back. Never a delete.
    func setSkipped(_ id: String, _ skipped: Bool) async throws {
        let at: String? = skipped ? ISO8601DateFormatter().string(from: Date()) : nil
        try await raw("rest/v1/transactions", query: [.init(name: "id", value: "eq.\(id)")], method: "PATCH",
                      body: ["skipped_at": at])
    }

    func renameValue(_ id: String, to name: String) async throws {
        try await raw("rest/v1/life_values", query: [.init(name: "id", value: "eq.\(id)")], method: "PATCH",
                      body: ["name": name.trimmingCharacters(in: .whitespaces)])
    }

    func deleteValue(_ id: String) async throws {
        try await raw("rest/v1/life_values", query: [.init(name: "id", value: "eq.\(id)")], method: "DELETE")
    }

    // MARK: - Writing the memo (only the person; agents are refused in SQL)

    func saveMemo(transactionID: String, body: String, valueIDs: [String]) async throws {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            try await raw("rest/v1/memos", query: [.init(name: "transaction_id", value: "eq.\(transactionID)")], method: "DELETE")
            return
        }
        try await raw("rest/v1/memos", query: [.init(name: "on_conflict", value: "transaction_id")], method: "POST",
                      body: ["transaction_id": transactionID, "body": text], prefer: "resolution=merge-duplicates")
        struct Link: Decodable { let value_id: String }
        let have: [Link] = try await rest("memo_values", [.init(name: "select", value: "value_id"),
                                                          .init(name: "transaction_id", value: "eq.\(transactionID)")])
        let haveIDs = Set(have.map(\.value_id)), want = Set(valueIDs)
        let drop = haveIDs.subtracting(want), add = want.subtracting(haveIDs)
        if !drop.isEmpty {
            try await raw("rest/v1/memo_values", query: [.init(name: "transaction_id", value: "eq.\(transactionID)"),
                                                         .init(name: "value_id", value: "in.(\(drop.joined(separator: ",")))")],
                          method: "DELETE")
        }
        if !add.isEmpty {
            try await raw("rest/v1/memo_values", method: "POST",
                          body: add.map { ["transaction_id": transactionID, "value_id": $0] })
        }
    }

    // MARK: - Import (idempotent on source_id, Decision 057)

    struct ImportResult { let inserted: Int; let skipped: Int }

    func importAppleCard(_ rows: [ImportRow], filename: String) async throws -> ImportResult {
        try await importExport(.applecard, rows, filename: filename)
    }

    /// Any exported source (S1/S2), each into its own account.
    func importExport(_ kind: Money.ExportKind, _ rows: [ImportRow], filename: String) async throws -> ImportResult {
        struct IDRow: Decodable { let id: String }
        let accountData = try await raw("rest/v1/accounts", query: [.init(name: "on_conflict", value: "user_id,source,source_id"),
                                                                    .init(name: "select", value: "id")], method: "POST",
                                        body: ["source": "csv", "source_id": kind.rawValue, "kind": kind.accountKind,
                                               "display_name": kind.displayName, "institution": kind.institution],
                                        prefer: "return=representation,resolution=merge-duplicates")
        guard let account = try JSONDecoder().decode([IDRow].self, from: accountData).first else { throw APIError.decoding("account") }
        let batchData = try await raw("rest/v1/import_batches", query: [.init(name: "select", value: "id")], method: "POST",
                                      body: ImportBatch(source: "csv", filename: String(filename.prefix(255)), row_count: rows.count),
                                      prefer: "return=representation")
        guard let batch = try JSONDecoder().decode([IDRow].self, from: batchData).first else { throw APIError.decoding("batch") }
        var inserted = 0
        for start in stride(from: 0, to: rows.count, by: 500) {
            let chunk = rows[start..<min(start + 500, rows.count)].map { UpsertRow(row: $0, accountID: account.id, batchID: batch.id) }
            let got = try await raw("rest/v1/transactions", query: [.init(name: "on_conflict", value: "user_id,source,source_id"),
                                                                    .init(name: "select", value: "id")], method: "POST",
                                    body: chunk, prefer: "return=representation,resolution=ignore-duplicates")
            inserted += try JSONDecoder().decode([IDRow].self, from: got).count
        }
        try await raw("rest/v1/import_batches", query: [.init(name: "id", value: "eq.\(batch.id)")], method: "PATCH",
                      body: ["inserted_count": inserted])
        return ImportResult(inserted: inserted, skipped: rows.count - inserted)
    }

    // MARK: - Attachments (by reference; money-story-design)

    struct Attachment: Decodable, Identifiable, Hashable {
        let id: String
        let kind: String
        let deviceRef: String?
        enum CodingKeys: String, CodingKey { case id, kind, deviceRef = "device_ref" }
    }

    func attachments(for transactionID: String) async throws -> [Attachment] {
        try await rest("attachments", [.init(name: "transaction_id", value: "eq." + transactionID),
                                      .init(name: "select", value: "id,kind,device_ref"),
                                      .init(name: "order", value: "created_at")])
    }

    /// Records a photo by its PhotoKit identifier only; no copy of the image leaves the device.
    func attachPhoto(transactionID: String, deviceRef: String) async throws -> Attachment {
        struct Row: Encodable { let transaction_id: String; let kind = "photo"; let device_ref: String }
        let data = try await raw("rest/v1/attachments", query: [.init(name: "select", value: "id,kind,device_ref")], method: "POST",
                                 body: Row(transaction_id: transactionID, device_ref: deviceRef), prefer: "return=representation")
        guard let made = try JSONDecoder().decode([Attachment].self, from: data).first else { throw APIError.decoding("no attachment returned") }
        return made
    }

    func removeAttachment(_ id: String) async throws {
        try await raw("rest/v1/attachments", query: [.init(name: "id", value: "eq." + id)], method: "DELETE")
    }

    // MARK: - FinanceKit sync (Decision 057: idempotent on source_id)

    /// Deletes every account that came from FinanceKit; its transactions,
    /// balances, memos, and attachments cascade. Used when access is revoked.
    func deleteFinanceKitData() async throws {
        try await raw("rest/v1/accounts", query: [.init(name: "source", value: "eq.financekit")], method: "DELETE")
    }

    /// Writes one batch of FinanceKit changes: accounts upserted by their
    /// FinanceKit id, transactions upserted as `source = 'financekit'`, and
    /// deletions applied. The connector never reads these rows (Addendum 3.2).
    func syncFinance(_ reported: FinanceChanges) async throws -> ImportResult {
        let changes = reported.normalized()   // one row per purchase per upsert
        struct IDRow: Decodable { let id: String; let source_id: String }
        var accountIDs: [String: String] = [:]
        if !changes.accounts.isEmpty {
            let data = try await raw("rest/v1/accounts", query: [.init(name: "on_conflict", value: "user_id,source,source_id"),
                                                                 .init(name: "select", value: "id,source_id")], method: "POST",
                                     body: changes.accounts.map { FinanceAccountRow(sourceID: $0.sourceID, kind: $0.kind, displayName: $0.displayName,
                                                                                     institution: $0.institution, currency: $0.currency,
                                                                                     creditLimitMinor: $0.creditLimitMinor) },
                                     prefer: "return=representation,resolution=merge-duplicates")
            for r in try JSONDecoder().decode([IDRow].self, from: data) { accountIDs[r.source_id] = r.id }
        }
        guard let fallback = changes.accounts.first.flatMap({ accountIDs[$0.sourceID] }) ?? accountIDs.values.first else {
            return ImportResult(inserted: 0, skipped: 0)
        }
        var inserted = 0
        if !changes.inserted.isEmpty {
            struct Row: Encodable {
                let row: ImportRow, accountID: String
                enum K: String, CodingKey { case account_id, source }
                func encode(to e: Encoder) throws {
                    try row.encode(to: e); var c = e.container(keyedBy: K.self)
                    try c.encode(accountID, forKey: .account_id); try c.encode("financekit", forKey: .source)
                }
            }
            for start in stride(from: 0, to: changes.inserted.count, by: 500) {
                let chunk = changes.inserted[start..<min(start + 500, changes.inserted.count)]
                    .map { Row(row: $0, accountID: $0.accountSourceID.flatMap { accountIDs[$0] } ?? fallback) }
                let got = try await raw("rest/v1/transactions", query: [.init(name: "on_conflict", value: "user_id,source,source_id"),
                                                                        .init(name: "select", value: "id,source_id")], method: "POST",
                                        body: chunk, prefer: "return=representation,resolution=merge-duplicates")
                inserted += try JSONDecoder().decode([IDRow].self, from: got).count
            }
        }
        if !changes.deletedSourceIDs.isEmpty {
            try await raw("rest/v1/transactions", query: [.init(name: "source", value: "eq.financekit"),
                                                          .init(name: "source_id", value: "in.(\(changes.deletedSourceIDs.joined(separator: ",")))")],
                          method: "DELETE")
        }
        return ImportResult(inserted: inserted, skipped: 0)
    }

    private struct ImportBatch: Encodable { let source: String; let filename: String; let row_count: Int }
    private struct UpsertRow: Encodable {
        let row: ImportRow, accountID: String, batchID: String
        enum K: String, CodingKey { case account_id, import_batch_id, source }
        func encode(to encoder: Encoder) throws {
            try row.encode(to: encoder)
            var c = encoder.container(keyedBy: K.self)
            try c.encode(accountID, forKey: .account_id)
            try c.encode(batchID, forKey: .import_batch_id)
            try c.encode("csv", forKey: .source)
        }
    }
}
