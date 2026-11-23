import Foundation

/// What the app and its Wallet extension both read (F2): the App Group's
/// defaults hold each person's FinanceKit history tokens, and the session's
/// Keychain item lives in the same group (Keychain.swift). Builds before F2
/// kept the tokens in standard defaults; the first read moves them over.
enum Shared {
    static let group = "group.com.learningischange.centmemo"

    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func financeToken(_ key: String) -> Data? {
        if let d = defaults.data(forKey: key) { return d }
        guard let old = UserDefaults.standard.data(forKey: key) else { return nil }
        defaults.set(old, forKey: key)
        if defaults !== UserDefaults.standard { UserDefaults.standard.removeObject(forKey: key) }
        return old
    }

    static func setFinanceToken(_ data: Data?, _ key: String) {
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
    }
}
