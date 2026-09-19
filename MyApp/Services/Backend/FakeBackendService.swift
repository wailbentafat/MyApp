import Foundation

/// Stands in for the Supabase backend described in the plan (Postgres + PostGIS
/// "nearby" query, Storage, RLS). Everything lives in memory for the lifetime of
/// the process, with an artificial network delay so the UI's loading states are
/// exercised honestly. No network call is ever made.
///
/// Swap this for a real Supabase-backed implementation later without touching a
/// single feature view — they only ever see `CleanUpRepository` / `ActivityRepository`.
actor FakeBackendService: CleanUpRepository, ActivityRepository, FeedService {
    private var cleanUps: [UUID: CleanUp]
    private var activities: [UUID: Activity] = [:]
    private var feedPosts: [FeedPost]
    private var continuations: [UUID: AsyncStream<[CleanUp]>.Continuation] = [:]

    init(seed: [CleanUp] = Fixtures.seedCleanUps(), feed: [FeedPost] = Fixtures.seedFeedPosts()) {
        self.cleanUps = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        self.feedPosts = feed
    }

    private func simulateLatency() async {
        try? await Task.sleep(for: .milliseconds(.random(in: 250...650)))
    }

    private func broadcast() {
        let all = Array(cleanUps.values).sorted { $0.createdAt > $1.createdAt }
        for continuation in continuations.values {
            continuation.yield(all)
        }
    }

    // MARK: CleanUpRepository

    func all() async throws -> [CleanUp] {
        await simulateLatency()
        return Array(cleanUps.values).sorted { $0.createdAt > $1.createdAt }
    }

    func nearby(coordinate: Coordinate, radiusMeters: Double) async throws -> [CleanUp] {
        await simulateLatency()
        return cleanUps.values
            .filter { $0.coordinate.distance(to: coordinate) <= radiusMeters }
            .sorted { $0.coordinate.distance(to: coordinate) < $1.coordinate.distance(to: coordinate) }
    }

    func cleanUp(id: UUID) async throws -> CleanUp? {
        await simulateLatency()
        return cleanUps[id]
    }

    @discardableResult
    func create(_ draft: CleanUpDraft, host: User) async throws -> CleanUp {
        await simulateLatency()
        let url = try? FakePhotoStore.shared.save(draft.beforePhotoData)
        let cleanUp = CleanUp(
            id: UUID(),
            title: draft.title,
            coordinate: draft.coordinate,
            beforePhotoURL: url,
            beforeHeading: draft.beforeHeading,
            wasteTypes: draft.wasteTypes,
            severity: draft.severity,
            estimatedBags: draft.estimatedBags,
            gear: draft.gear,
            hazard: draft.hazard,
            startsAt: draft.startsAt,
            capacity: draft.capacity,
            hostId: host.id,
            hostName: host.name,
            status: draft.startsAt == nil ? .open : .scheduled,
            attendeeIds: [host.id],
            doneActivityIds: [],
            createdAt: Date()
        )
        cleanUps[cleanUp.id] = cleanUp
        broadcast()
        return cleanUp
    }

    @discardableResult
    func setRSVP(cleanUpId: UUID, userId: UUID, joining: Bool) async throws -> CleanUp {
        await simulateLatency()
        guard var cleanUp = cleanUps[cleanUpId] else {
            throw FakeBackendError.notFound
        }
        if joining {
            if !cleanUp.attendeeIds.contains(userId) { cleanUp.attendeeIds.append(userId) }
        } else {
            cleanUp.attendeeIds.removeAll { $0 == userId }
        }
        cleanUps[cleanUpId] = cleanUp
        broadcast()
        return cleanUp
    }

    @discardableResult
    func updateStatus(cleanUpId: UUID, status: CleanUpStatus) async throws -> CleanUp {
        await simulateLatency()
        guard var cleanUp = cleanUps[cleanUpId] else {
            throw FakeBackendError.notFound
        }
        cleanUp.status = status
        cleanUps[cleanUpId] = cleanUp
        broadcast()
        return cleanUp
    }

    @discardableResult
    func complete(cleanUpId: UUID, activityId: UUID) async throws -> CleanUp {
        await simulateLatency()
        guard var cleanUp = cleanUps[cleanUpId] else {
            throw FakeBackendError.notFound
        }
        cleanUp.status = .done
        if !cleanUp.doneActivityIds.contains(activityId) { cleanUp.doneActivityIds.append(activityId) }
        cleanUps[cleanUpId] = cleanUp
        broadcast()
        return cleanUp
    }

    nonisolated func changes() -> AsyncStream<[CleanUp]> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<[CleanUp]>.Continuation) {
        continuations[id] = continuation
        continuation.yield(Array(cleanUps.values).sorted { $0.createdAt > $1.createdAt })
    }

    private func unregister(id: UUID) {
        continuations[id] = nil
    }

    // MARK: ActivityRepository

    func save(_ activity: Activity) async throws {
        activities[activity.id] = activity
    }

    func history(userId: UUID) async throws -> [Activity] {
        await simulateLatency()
        return activities.values
            .filter { $0.userId == userId }
            .sorted { $0.startedAt > $1.startedAt }
    }

    @discardableResult
    func upload(_ activity: Activity) async throws -> Activity {
        await simulateLatency()
        activities[activity.id] = activity
        return activity
    }

    // MARK: FeedService

    func recentPosts() async throws -> [FeedPost] {
        await simulateLatency()
        return feedPosts.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func toggleKudos(postId: UUID, userId: UUID) async throws -> FeedPost {
        await simulateLatency()
        guard let index = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw FakeBackendError.notFound
        }
        var post = feedPosts[index]
        post.kudosGivenByMe.toggle()
        post.kudosCount += post.kudosGivenByMe ? 1 : -1
        feedPosts[index] = post
        return post
    }

    /// Appends a finished activity to the feed as a new post — used by the Activity
    /// placeholder flow so "finish → feed" is demoable end to end without P1's real engine.
    func publish(activity: Activity, cleanUp: CleanUp, author: User) async {
        let post = FeedPost(
            id: UUID(), activityId: activity.id, authorId: author.id,
            authorName: author.name, authorAvatarSystemImage: author.avatarSystemImage,
            cleanUpTitle: cleanUp.title,
            beforePhotoURL: cleanUp.beforePhotoURL, afterPhotoURL: activity.afterPhotoURL,
            distanceKm: activity.distance / 1000, kcal: activity.kcal, bags: activity.impactLog.bags,
            kudosCount: 0, kudosGivenByMe: false,
            createdAt: Date()
        )
        feedPosts.insert(post, at: 0)
    }
}

enum FakeBackendError: Error {
    case notFound
}
