import Foundation
import Observation

/// Home tab: activity streak, Clean-Ups near you, community feed.
@Observable @MainActor
final class HomeViewModel {
    private(set) var posts: [FeedPost] = []
    private(set) var nearbyCleanUps: [CleanUp] = []
    private(set) var weeklyStreak = 0
    private(set) var isLoading = false

    let user: User
    private let feed: FeedService
    private let cleanUps: CleanUpRepository
    private let activities: ActivityRepository
    private let now: () -> Date
    private let calendar: Calendar
    private let reference: Coordinate

    init(user: User, feed: FeedService, cleanUps: CleanUpRepository, activities: ActivityRepository,
         reference: Coordinate = Fixtures.homeCoordinate,
         now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.user = user
        self.feed = feed
        self.cleanUps = cleanUps
        self.activities = activities
        self.reference = reference
        self.now = now
        self.calendar = calendar
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        posts = (try? await feed.recentPosts()) ?? []
        let all = (try? await cleanUps.all()) ?? []
        nearbyCleanUps = all
            .filter { $0.status != .done }
            .sorted { distance(to: $0) < distance(to: $1) }
        let history = (try? await activities.history(userId: user.id)) ?? []
        weeklyStreak = Self.weeklyStreak(activityDates: history.map(\.startedAt), now: now(), calendar: calendar)
    }

    func toggleKudos(_ post: FeedPost) async {
        guard let updated = try? await feed.toggleKudos(postId: post.id, userId: user.id),
              let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = updated
    }

    func toggleRSVP(_ cleanUp: CleanUp) async {
        let joining = !isAttending(cleanUp)
        guard let updated = try? await cleanUps.setRSVP(cleanUpId: cleanUp.id, userId: user.id, joining: joining),
              let index = nearbyCleanUps.firstIndex(where: { $0.id == cleanUp.id }) else { return }
        nearbyCleanUps[index] = updated
    }

    func isAttending(_ cleanUp: CleanUp) -> Bool { cleanUp.attendeeIds.contains(user.id) }

    // MARK: Display

    var streakTitle: String {
        weeklyStreak == 0 ? "Start your streak by logging a cleanup." : "\(weeklyStreak)-week streak. Keep it going!"
    }

    var streakBadge: String { String(weeklyStreak) }

    func distanceText(to cleanUp: CleanUp) -> String {
        let meters = distance(to: cleanUp)
        return meters < 1000 ? "\(Int(meters.rounded())) m away" : String(format: "%.1f km away", meters / 1000)
    }

    func rsvpTitle(for cleanUp: CleanUp) -> String {
        isAttending(cleanUp) ? "Going" : (cleanUp.isFull ? "Full" : "RSVP")
    }

    private func distance(to cleanUp: CleanUp) -> Double { reference.distance(to: cleanUp.coordinate) }

    /// Consecutive weeks (ending this week, or last week if this week is still empty) with at least one activity.
    static func weeklyStreak(activityDates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        }
        let weeks = Set(activityDates.map(weekStart))
        var cursor = weekStart(now)
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
