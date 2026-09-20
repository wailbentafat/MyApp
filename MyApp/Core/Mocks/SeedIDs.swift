import Foundation

/// Stable IDs for the seeded demo records, so notifications, comments and posts can reference each other,
/// reseeding is idempotent, and persisted files stay valid across launches.
enum SeedIDs {
    private static func make(_ kind: Int, _ index: Int) -> UUID {
        UUID(uuidString: String(format: "5EED%04X-0000-4000-8000-%012d", kind, index))!
    }

    static func cleanUp(_ index: Int) -> UUID { make(1, index) }
    static func post(_ index: Int) -> UUID { make(2, index) }
    /// The activity behind a community feed post (someone else's activity, not in my history).
    static func feedActivity(_ index: Int) -> UUID { make(3, index) }
    /// My own seeded activities (Profile history).
    static func activity(_ index: Int) -> UUID { make(4, index) }
    static func comment(_ index: Int) -> UUID { make(5, index) }

    static let cleanUpIDs: Set<UUID> = Set((1...8).map(cleanUp))
}
