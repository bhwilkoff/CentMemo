import Foundation
import Security

/// The session lives in the Keychain, never in UserDefaults (AGENTS.md: secrets
/// never in cleartext on disk). This-device-only: a restored backup signs out.
/// The Wallet extension shares it through the App Group (Shared.group).
enum Keychain {
    private static let service = "com.learningischange.centmemo.session"

    static func save(_ data: Data, account: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // In the App Group, so the Wallet extension (F2) reads the same session.
        // Builds without the group entitlement (Core tests on the Mac) keep the
        // default group. Reads search every group, so older items still load.
        var grouped = add
        grouped[kSecAttrAccessGroup as String] = Shared.group
        if SecItemAdd(grouped as CFDictionary, nil) != errSecSuccess { SecItemAdd(add as CFDictionary, nil) }
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    static func delete(account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: account] as CFDictionary)
    }
}
