import Foundation
import Observation

/// You tab: totals, badges, and every activity (each one opens its share preview).
@Observable @MainActor
final class ProfileViewModel {
    struct Row: Identifiable {
        let activity: Activity
        let title: String
        let dateText: String
        let statsText: String
        let photoURL: URL?
        var id: UUID { activity.id }
    }

    private(set) var history: [Activity] = []
    var selectedActivity: Activity?
    let badges: [Badge]

    let user: User?
    private let activities: ActivityRepository

    init(user: User?, activities: ActivityRepository, badges: [Badge] = Fixtures.seedBadges()) {
        self.user = user
        self.activities = activities
        self.badges = badges
    }

    func load() async {
        guard let user else { return }
        history = (try? await activities.history(userId: user.id)) ?? []
    }

    // MARK: Header & totals

    var displayName: String { user?.name ?? "hɛal" }
    var cleanUpsText: String { "\(user?.totals.cleanUpsJoined ?? 0)" }
    var bagsText: String { "\(user?.totals.bagsCollected ?? 0)" }
    var distanceText: String { String(format: "%.0f km", user?.totals.distanceKm ?? 0) }
    var bottlesText: String { "≈ \((user?.totals.bagsCollected ?? 0) * 45) plastic bottles kept out of waterways" }

    // MARK: History

    var rows: [Row] {
        history.map { activity in
            Row(
                activity: activity,
                title: activity.title,
                dateText: activity.startedAt.formatted(date: .abbreviated, time: .shortened),
                statsText: String(format: "%.1f km · %@ · %d bags", activity.distance / 1000,
                                  ActivityViewModel.formatDuration(activity.duration), activity.impactLog.bags),
                photoURL: thumbnailURL(for: activity)
            )
        }
    }

    var hasHistory: Bool { !history.isEmpty }

    func open(_ row: Row) { selectedActivity = row.activity }
    func closePreview() { selectedActivity = nil }

    /// The activity's own photo, else a volunteer photo (fake data), so rows never show an empty box.
    func thumbnailURL(for activity: Activity) -> URL? {
        if let url = activity.afterPhotoURL ?? activity.beforePhotoURL { return url }
        let names = DemoPhotos.crewNames
        return DemoPhotos.url(names[Int(activity.id.uuid.0) % names.count])
    }
}
