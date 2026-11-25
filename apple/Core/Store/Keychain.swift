import Foundation
import Security

/// The session lives in the Keychain, never in UserDefaults (AGENTS.md: secrets
/// never in cleartext on disk). This-device-only: a restored backup signs out.
/// The Wallet extension shares it through the App Group (Shared.group).
nonisolated enum Keychain {
    /// On a Mac a test run is the same app as the TestFlight one, so it keeps its fake
    /// sign-in in a slot of its own and never reads or replaces the person's.
    private static let service: String = {
        let real = "com.learningischange.centmemo.session"
        #if DEBUG && os(macOS)
        if ProcessInfo.processInfo.environment["APP_TEST_EMAIL"] != nil { return real + ".test" }
        #endif
        return real
    }()

    /// The Mac keeps it in the data protection keychain, as the phone does: the older
    /// file keychain asks for the Mac's password whenever the app's signature changes.
    /// An unsigned build (the Core tests) has no such keychain, and uses the file one.
    private static func item(_ account: String, protected: Bool) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        #if os(macOS)
        if protected { q[kSecUseDataProtectionKeychain as String] = true }
        #endif
        return q
    }

    static func save(_ data: Data, account: String) {
        let base = item(account, protected: true)
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // In the App Group, so the Wallet extension (F2) reads the same session.
        // Builds without the group entitlement (the Mac, Core tests) keep the default
        // group. Reads search every group, so older items still load.
        var grouped = add
        grouped[kSecAttrAccessGroup as String] = Shared.group
        if SecItemAdd(grouped as CFDictionary, nil) == errSecSuccess { return }
        if SecItemAdd(add as CFDictionary, nil) == errSecSuccess { return }
        #if os(macOS)
        var plain = item(account, protected: false)
        SecItemDelete(plain as CFDictionary)
        plain[kSecValueData as String] = data
        SecItemAdd(plain as CFDictionary, nil)
        #endif
    }

    static func load(account: String) -> Data? {
        func read(_ protected: Bool) -> Data? {
            var q = item(account, protected: protected)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: AnyObject?
            return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
        }
        return read(true)
    }

    static func delete(account: String) {
        SecItemDelete(item(account, protected: true) as CFDictionary)
    }
}
