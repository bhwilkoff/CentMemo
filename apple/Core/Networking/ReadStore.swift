import CryptoKit
import Foundation

/// What the server last answered, kept on this device so CentMemo opens at once and
/// refreshes behind what it shows. Encrypted with a key that lives in the Keychain, named
/// by person, in Caches (never backed up), and erased when the person changes.
/// The Wallet extension neither reads nor erases it.
nonisolated enum ReadStore {
    private static let keyName = "reads-key"
    private static let limit = 150
    private static let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    private static let queue = DispatchQueue(label: "centmemo.reads")

    private static var folder: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appending(path: "reads", directoryHint: .isDirectory)
    }

    private static func file(_ name: String) -> URL? {
        let digest = SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder?.appending(path: digest)
    }

    /// Guarded by `queue`.
    nonisolated(unsafe) private static var held: SymmetricKey?

    private static func key(making: Bool) -> SymmetricKey? {
        if let held { return held }
        if let data = Keychain.load(account: keyName), data.count == 32 { held = SymmetricKey(data: data); return held }
        guard making else { return nil }
        let fresh = SymmetricKey(size: .bits256)
        Keychain.save(fresh.withUnsafeBytes { Data($0) }, account: keyName)
        held = fresh
        return fresh
    }

    static func load(_ name: String) -> Data? {
        guard !isExtension else { return nil }
        return queue.sync {
            guard let url = file(name), let sealed = try? Data(contentsOf: url), let key = key(making: false),
                  let box = try? AES.GCM.SealedBox(combined: sealed) else { return nil }
            return try? AES.GCM.open(box, using: key)
        }
    }

    /// `current` is asked on the queue, so a save that lost a race with a sign-out writes nothing.
    static func save(_ data: Data, as name: String, if current: @escaping @Sendable () -> Bool) {
        guard !isExtension else { return }
        queue.async {
            guard current(), let folder, let url = file(name), let key = key(making: true),
                  let sealed = try? AES.GCM.seal(data, using: key).combined else { return }
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            #if os(macOS)
            try? sealed.write(to: url, options: .atomic)
            #else
            try? sealed.write(to: url, options: [.atomic, .completeFileProtection])
            #endif
        }
    }

    static func wipe() {
        guard !isExtension else { return }
        queue.sync {
            if let folder { try? FileManager.default.removeItem(at: folder) }
            Keychain.delete(account: keyName)
            held = nil
        }
    }

    /// The newest answers only, and the old cleartext response cache gone (builds up to
    /// 1.0.32 let URLSession keep answers, sign-ins included, in Caches/<bundle>/Cache.db).
    static func tidy() {
        queue.async {
            let fm = FileManager.default
            if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first, let id = Bundle.main.bundleIdentifier {
                let old = caches.appending(path: id)
                for n in ["Cache.db", "Cache.db-shm", "Cache.db-wal", "fsCachedData"] { try? fm.removeItem(at: old.appending(path: n)) }
            }
            guard !isExtension, let folder,
                  let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]), files.count > limit else { return }
            func age(_ u: URL) -> Date { (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
            for f in files.sorted(by: { age($0) > age($1) }).dropFirst(limit) { try? fm.removeItem(at: f) }
        }
    }
}
