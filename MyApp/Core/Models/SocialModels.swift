import Foundation

/// A comment on an activity / post.
struct Comment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    /// The activity (or feed post's activity) the comment belongs to.
    var targetId: UUID
    var authorId: UUID
    var authorName: String
    var text: String
    var createdAt: Date
}

/// Someone who gave an Eco-Boost (like), stored with their name so the UI needs no user directory.
struct BoosterRef: Codable, Hashable, Sendable {
    var userId: UUID
    var name: String
}
