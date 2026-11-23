import Foundation

/// Test "doors": launch env vars that open a screen directly, so a harness
/// (`simctl launch`, `devicectl ... --environment-variables`, a Mac exec) can
/// reach any surface without pressing blind. Names match tools/app_config.py
/// (HOOK_START_TAB, HOOK_START_ITEM, HOOK_MUTE, HOOK_DOOR_SECONDS).
///
/// DEBUG-only: in a Release build `current` is always empty, so every door is a
/// no-op in production. Doors never touch the router directly — they are posted
/// to the AppStore inbox and consumed by RootView like any other deep link.
struct LaunchDoors: Sendable, Equatable {
    var startTab: String?
    var startItem: String?
    /// D8: a Setting's page by its cleaned name (APP_START_SETTING).
    var startSetting: String?
    var mute = false
    var doorSeconds: Int?
    /// D14: show the first-run starter themes even when themes exist (APP_FIRST_THEMES=1).
    var firstThemes = false

    var isEmpty: Bool { self == LaunchDoors() }

    static let current: LaunchDoors = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return LaunchDoors(
            startTab: environment["APP_START_TAB"],
            startItem: environment["APP_START_ITEM"],
            startSetting: environment["APP_START_SETTING"],
            mute: environment["APP_MUTE"] == "1",
            doorSeconds: environment["APP_DOOR_SECONDS"].flatMap { Int($0) },
            firstThemes: environment["APP_FIRST_THEMES"] == "1"
        )
        #else
        return LaunchDoors()
        #endif
    }()
}
