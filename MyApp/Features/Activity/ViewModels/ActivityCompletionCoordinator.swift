import Foundation

/// What happens after an activity is saved: upload it, close its Clean-Up, publish it to the community feed.
/// Shared by every place that can finish an activity (Clean-Up detail, Record sheet).
@MainActor
final class ActivityCompletionCoordinator {
    private let activities: ActivityRepository
    private let cleanUps: CleanUpRepository
    private let feed: FeedService

    init(activities: ActivityRepository, cleanUps: CleanUpRepository, feed: FeedService) {
        self.activities = activities
        self.cleanUps = cleanUps
        self.feed = feed
    }

    func complete(_ activity: Activity, cleanUp: CleanUp?, author: User) async {
        _ = try? await activities.upload(activity)
        guard let cleanUp else { return }
        let updated = (try? await cleanUps.complete(cleanUpId: cleanUp.id, activityId: activity.id)) ?? cleanUp
        await feed.publish(activity: activity, cleanUp: updated, author: author)
    }
}
