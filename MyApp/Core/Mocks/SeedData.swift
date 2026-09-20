import Foundation

/// Everything the fake backend starts with (first launch and "Reset demo data").
struct SeedBundle {
    var cleanUps: [CleanUp]
    var feedPosts: [FeedPost]
    var activities: [Activity]
    var comments: [Comment]
    var boosts: [String: [BoosterRef]]
    var notifications: [AppNotification]
}

enum SeedData {
    static func make() -> SeedBundle {
        SeedBundle(
            cleanUps: Fixtures.seedCleanUps(),
            feedPosts: Fixtures.seedFeedPosts(),
            activities: Fixtures.seedActivities(),
            comments: Fixtures.seedComments(),
            boosts: Fixtures.seedBoosts(),
            notifications: Fixtures.seedNotifications()
        )
    }
}

/// Keeps the demo calendar alive: seed Clean-Ups that are still open/scheduled but whose date has passed are moved
/// forward by whole weeks, so "Upcoming" is never empty. User state (RSVPs, status) is untouched.
enum SeedRefresher {
    static func refreshed(_ cleanUps: [CleanUp], now: Date = .now, calendar: Calendar = .current) -> [CleanUp] {
        let today = calendar.startOfDay(for: now)
        return cleanUps.map { cleanUp in
            guard SeedIDs.cleanUpIDs.contains(cleanUp.id),
                  cleanUp.status == .scheduled || cleanUp.status == .open,
                  let startsAt = cleanUp.startsAt, startsAt < today else { return cleanUp }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startsAt), to: today).day ?? 0
            let weeks = Int((Double(days) / 7).rounded(.up))
            var moved = cleanUp
            moved.startsAt = calendar.date(byAdding: .day, value: weeks * 7, to: startsAt)
            return moved
        }
    }
}
