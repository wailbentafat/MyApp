import Foundation

enum NotificationKind: String, Codable, CaseIterable, Sendable {
    /// Someone gave an Eco-Boost (like) to one of my activities.
    case activityLike
    /// Someone commented on one of my activities.
    case comment
    /// Community reactions: likes on my Clean-Ups and posts, from several people.
    case communityLike
}

/// What a notification opens.
enum NotificationTarget: Codable, Hashable, Sendable {
    /// An activity / post (mine, or a community feed post's activity).
    case activity(UUID)
    case cleanUp(UUID)
}

struct AppNotification: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var kind: NotificationKind
    var target: NotificationTarget
    /// The comment to scroll to and highlight on the post screen.
    var commentID: UUID?
    var actorName: String
    /// Extra people beyond `actorName` ("Priya and 4 others").
    var otherActorsCount = 0
    /// Title of the activity / Clean-Up the notification is about.
    var subject: String
    var commentText: String?
    var photoURL: URL?
    var createdAt: Date
    var isRead: Bool
}
