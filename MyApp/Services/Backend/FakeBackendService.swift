import Foundation

/// The persisted state of the fake backend (one JSON file). Dictionaries are keyed by uuidString so the JSON stays
/// readable.
struct BackendState: Codable {
    var cleanUps: [CleanUp]
    var activities: [Activity]
    var feedPosts: [FeedPost]
    var comments: [Comment]
    var boosts: [String: [BoosterRef]]
}

/// Stands in for the Supabase backend described in the plan (Postgres + PostGIS "nearby" query, Storage, RLS).
/// State lives in memory and is written through to a `DocumentStore` (JSON files in the app), so activities, RSVPs,
/// kudos and comments survive relaunches. An artificial network delay keeps the UI's loading states honest.
/// No network call is ever made.
///
/// Swap this for a real Supabase-backed implementation later without touching a single feature view — they only ever
/// see the repository / service protocols.
actor FakeBackendService: CleanUpRepository, ActivityRepository, FeedService, SocialService, DemoDataResetting {
    static let storeName = "backend"

    private var cleanUps: [UUID: CleanUp] = [:]
    private var activities: [UUID: Activity] = [:]
    private var feedPosts: [FeedPost] = []
    private var comments: [Comment] = []
    private var boosts: [String: [BoosterRef]] = [:]

    private var continuations: [UUID: AsyncStream<[CleanUp]>.Continuation] = [:]
    private var activityStreams: [UUID: (userId: UUID, continuation: AsyncStream<[Activity]>.Continuation)] = [:]
    private var feedStreams: [UUID: AsyncStream<[FeedPost]>.Continuation] = [:]

    private let store: DocumentStore
    private let persistDelay: Duration
    private let latency: ClosedRange<Int>
    private let now: () -> Date
    private var saveTask: Task<Void, Never>?
    private var uploadHook: (@Sendable (Activity) async -> Void)?

    /// - Parameters:
    ///   - store: where state is saved. Defaults to memory (tests, previews); the app passes `JSONDocumentStore`.
    ///   - seed: initial data when the store is empty. Defaults to `SeedData.make()`.
    ///   - persistDelay: debounce for writes; `.zero` writes synchronously (tests).
    ///   - latency: simulated network delay in milliseconds.
    init(
        store: DocumentStore = InMemoryDocumentStore(),
        seed: SeedBundle? = nil,
        persistDelay: Duration = .zero,
        latency: ClosedRange<Int> = 250...650,
        now: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.persistDelay = persistDelay
        self.latency = latency
        self.now = now

        let state: BackendState
        if let saved = store.load(BackendState.self, name: Self.storeName) {
            state = saved
        } else {
            let bundle = seed ?? SeedData.make()
            state = BackendState(cleanUps: bundle.cleanUps, activities: bundle.activities, feedPosts: bundle.feedPosts,
                                 comments: bundle.comments, boosts: bundle.boosts)
        }
        self.cleanUps = Dictionary(
            uniqueKeysWithValues: SeedRefresher.refreshed(state.cleanUps, now: now()).map { ($0.id, $0) }
        )
        self.activities = Dictionary(uniqueKeysWithValues: state.activities.map { ($0.id, $0) })
        self.feedPosts = state.feedPosts
        self.comments = state.comments
        self.boosts = state.boosts
        try? store.save(Self.snapshot(cleanUps: cleanUps, activities: activities, feedPosts: feedPosts,
                                      comments: comments, boosts: boosts), name: Self.storeName)
    }

    // MARK: Persistence

    private static func snapshot(cleanUps: [UUID: CleanUp], activities: [UUID: Activity], feedPosts: [FeedPost],
                                 comments: [Comment], boosts: [String: [BoosterRef]]) -> BackendState {
        BackendState(
            cleanUps: cleanUps.values.sorted { $0.createdAt < $1.createdAt },
            activities: activities.values.sorted { $0.startedAt < $1.startedAt },
            feedPosts: feedPosts, comments: comments, boosts: boosts
        )
    }

    private func writeNow() {
        try? store.save(Self.snapshot(cleanUps: cleanUps, activities: activities, feedPosts: feedPosts,
                                      comments: comments, boosts: boosts), name: Self.storeName)
    }

    private func persist() {
        guard persistDelay > .zero else { writeNow(); return }
        saveTask?.cancel()
        saveTask = Task { [persistDelay] in
            try? await Task.sleep(for: persistDelay)
            guard !Task.isCancelled else { return }
            writeNow()
        }
    }

    /// Writes immediately (called when the app goes to the background).
    func flush() {
        saveTask?.cancel()
        writeNow()
    }

    func resetToSeed() async {
        let bundle = SeedData.make()
        cleanUps = Dictionary(uniqueKeysWithValues: SeedRefresher.refreshed(bundle.cleanUps, now: now()).map { ($0.id, $0) })
        activities = Dictionary(uniqueKeysWithValues: bundle.activities.map { ($0.id, $0) })
        feedPosts = bundle.feedPosts
        comments = bundle.comments
        boosts = bundle.boosts
        writeNow()
        broadcast()
        broadcastActivities()
        broadcastFeed()
    }

    /// Lets a simulator react to newly uploaded activities (fake likes/comments arriving later).
    func setUploadHook(_ hook: (@Sendable (Activity) async -> Void)?) {
        uploadHook = hook
    }

    private func simulateLatency() async {
        guard latency.upperBound > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Int.random(in: latency)))
    }

    private func broadcast() {
        let all = Array(cleanUps.values).sorted { $0.createdAt > $1.createdAt }
        for continuation in continuations.values {
            continuation.yield(all)
        }
    }

    private func sortedActivities(for userId: UUID) -> [Activity] {
        activities.values.filter { $0.userId == userId }.sorted { $0.startedAt > $1.startedAt }
    }

    private func broadcastActivities() {
        for entry in activityStreams.values {
            entry.continuation.yield(sortedActivities(for: entry.userId))
        }
    }

    private func broadcastFeed() {
        let posts = feedPosts.sorted { $0.createdAt > $1.createdAt }
        for continuation in feedStreams.values { continuation.yield(posts) }
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
            createdAt: now()
        )
        cleanUps[cleanUp.id] = cleanUp
        persist()
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
        persist()
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
        persist()
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
        persist()
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
        persist()
        broadcastActivities()
    }

    func history(userId: UUID) async throws -> [Activity] {
        await simulateLatency()
        return sortedActivities(for: userId)
    }

    @discardableResult
    func upload(_ activity: Activity) async throws -> Activity {
        await simulateLatency()
        activities[activity.id] = activity
        persist()
        broadcastActivities()
        if let hook = uploadHook {
            Task { await hook(activity) }
        }
        return activity
    }

    nonisolated func changes(userId: UUID) -> AsyncStream<[Activity]> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.registerActivityStream(id: id, userId: userId, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterActivityStream(id: id) }
            }
        }
    }

    private func registerActivityStream(id: UUID, userId: UUID, continuation: AsyncStream<[Activity]>.Continuation) {
        activityStreams[id] = (userId, continuation)
        continuation.yield(sortedActivities(for: userId))
    }

    private func unregisterActivityStream(id: UUID) {
        activityStreams[id] = nil
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
        applyBoost(on: feedPosts[index].activityId, userId: userId, name: displayName(for: userId))
        persist()
        broadcastFeed()
        return feedPosts[index]
    }

    /// Appends a finished activity to the feed as a new post.
    func publish(activity: Activity, cleanUp: CleanUp, author: User) async {
        let post = FeedPost(
            id: UUID(), activityId: activity.id, authorId: author.id,
            authorName: author.name, authorAvatarSystemImage: author.avatarSystemImage,
            cleanUpTitle: cleanUp.title,
            beforePhotoURL: cleanUp.beforePhotoURL, afterPhotoURL: activity.afterPhotoURL,
            distanceKm: activity.distance / 1000, kcal: activity.kcal, bags: activity.impactLog.bags,
            kudosCount: 0, kudosGivenByMe: false,
            createdAt: now()
        )
        feedPosts.insert(post, at: 0)
        persist()
        broadcastFeed()
    }

    nonisolated func changes() -> AsyncStream<[FeedPost]> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.registerFeedStream(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterFeedStream(id: id) }
            }
        }
    }

    private func registerFeedStream(id: UUID, continuation: AsyncStream<[FeedPost]>.Continuation) {
        feedStreams[id] = continuation
        continuation.yield(feedPosts.sorted { $0.createdAt > $1.createdAt })
    }

    private func unregisterFeedStream(id: UUID) {
        feedStreams[id] = nil
    }

    // MARK: SocialService

    func comments(for activityId: UUID) async -> [Comment] {
        await simulateLatency()
        return comments.filter { $0.targetId == activityId }.sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(text: String, on activityId: UUID, by user: User) async throws -> Comment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { throw FakeBackendError.invalid }
        await simulateLatency()
        let comment = Comment(targetId: activityId, authorId: user.id, authorName: user.name, text: trimmed, createdAt: now())
        comments.append(comment)
        persist()
        return comment
    }

    func boostSummary(for activityId: UUID, userId: UUID) async -> BoostSummary {
        summary(for: activityId, userId: userId)
    }

    @discardableResult
    func toggleBoost(on activityId: UUID, by user: User) async -> BoostSummary {
        await simulateLatency()
        applyBoost(on: activityId, userId: user.id, name: user.name)
        persist()
        broadcastFeed()
        return summary(for: activityId, userId: user.id)
    }

    /// Adds a boost/comment on behalf of a simulated person (no latency).
    func addSimulatedBoost(on activityId: UUID, by user: User) {
        guard !(boosts[activityId.uuidString] ?? []).contains(where: { $0.userId == user.id }) else { return }
        applyBoost(on: activityId, userId: user.id, name: user.name)
        persist()
        broadcastFeed()
    }

    func addSimulatedComment(_ text: String, on activityId: UUID, by user: User) -> Comment {
        let comment = Comment(targetId: activityId, authorId: user.id, authorName: user.name, text: text, createdAt: now())
        comments.append(comment)
        persist()
        return comment
    }

    // MARK: Helpers

    private func applyBoost(on activityId: UUID, userId: UUID, name: String) {
        let key = activityId.uuidString
        var refs = boosts[key] ?? []
        let already = refs.contains { $0.userId == userId }
        if already {
            refs.removeAll { $0.userId == userId }
        } else {
            refs.append(BoosterRef(userId: userId, name: name))
        }
        boosts[key] = refs
        for index in feedPosts.indices where feedPosts[index].activityId == activityId {
            feedPosts[index].kudosCount = max(0, feedPosts[index].kudosCount + (already ? -1 : 1))
            if userId == User.demo.id { feedPosts[index].kudosGivenByMe = !already }
        }
    }

    private func summary(for activityId: UUID, userId: UUID) -> BoostSummary {
        let refs = boosts[activityId.uuidString] ?? []
        let count = feedPosts.first { $0.activityId == activityId }?.kudosCount ?? refs.count
        return BoostSummary(count: count, isBoostedByMe: refs.contains { $0.userId == userId }, names: refs.map(\.name))
    }

    private func displayName(for userId: UUID) -> String {
        ([User.demo] + Fixtures.demoUsers).first { $0.id == userId }?.name ?? "Someone"
    }
}

enum FakeBackendError: Error {
    case notFound
    case invalid
}
