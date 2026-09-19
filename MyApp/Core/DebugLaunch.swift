import Foundation

/// DEBUG-only launch arguments used to jump to a screen (screenshots, quick manual checks):
/// `-ecoAutoSignIn`, `-ecoTab home|map|cleanUps|profile`, `-ecoShow record|activity|activityCleanUp|spot`.
enum DebugLaunch {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    static var autoSignIn: Bool { arguments.contains("-ecoAutoSignIn") }

    static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    #else
    static var autoSignIn: Bool { false }
    static func value(after flag: String) -> String? { nil }
    #endif
}
