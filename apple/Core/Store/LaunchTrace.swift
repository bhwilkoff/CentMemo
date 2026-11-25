import Foundation

/// How long opening takes, in milliseconds since the process began. DEBUG, and only with
/// APP_LAUNCH_DIAG=1 (AGENTS.md: diagnostics stay, env-gated). Paths and sizes, never rows.
enum LaunchTrace {
    #if DEBUG
    private static let on = ProcessInfo.processInfo.environment["APP_LAUNCH_DIAG"] == "1"
    private static let start: Double = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return Date().timeIntervalSince1970 }
        let t = info.kp_proc.p_starttime
        return Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000
    }()
    static var now: Double { on ? (Date().timeIntervalSince1970 - start) * 1000 : 0 }
    static func mark(_ what: String, since began: Double? = nil) {
        guard on else { return }
        let t = now
        print("LAUNCH \(Int(t))ms \(what)" + (began.map { " took \(Int(t - $0))ms" } ?? ""))
    }
    #else
    static var now: Double { 0 }
    static func mark(_ what: String, since began: Double? = nil) {}
    #endif
}
