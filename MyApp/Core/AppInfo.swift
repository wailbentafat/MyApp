import Foundation

/// Product naming in one place. The brand is written with an epsilon: hɛal.
enum AppInfo {
    static let name = "hɛal"
    /// Meta (Facebook) App ID that Instagram requires when sharing to Stories. Set `INSTAGRAM_APP_ID` in
    /// `Local.xcconfig`; without it Instagram shows "the app you shared from doesn't support sharing to Stories",
    /// so `ShareService` falls back to the system share sheet instead.
    static var instagramAppID: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "InstagramAppID") as? String)?
            .trimmingCharacters(in: .whitespaces)
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    static let tagline = "Turn every walk into a cleanup."
}
