import XCTest
@testable import MyApp

// MARK: - Storage layer

final class DocumentStoreTests: XCTestCase {
    private struct Payload: Codable, Equatable {
        var name: String
        var photo: URL?
        var date: Date
    }

    func testRoundTripThroughInMemoryStore() throws {
        let store = InMemoryDocumentStore()
        let payload = Payload(name: "a", photo: URL(string: "https://example.com/x.jpg"), date: Date(timeIntervalSince1970: 1_800_000_000))
        try store.save(payload, name: "p")
        XCTAssertEqual(store.load(Payload.self, name: "p"), payload)
        XCTAssertNil(store.load(Payload.self, name: "missing"))
    }

    func testRoundTripThroughJSONFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("heal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = JSONDocumentStore(directory: dir)
        let payload = Payload(name: "file", photo: nil, date: Date(timeIntervalSince1970: 1_800_000_000))
        try store.save(payload, name: "p")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("p.json").path))
        XCTAssertEqual(JSONDocumentStore(directory: dir).load(Payload.self, name: "p"), payload, "a new store instance reads it back")
        store.removeAll()
        XCTAssertNil(store.load(Payload.self, name: "p"))
    }

    func testCorruptFileIsQuarantined() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("heal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("p.json"))
        let store = JSONDocumentStore(directory: dir)
        XCTAssertNil(store.load(Payload.self, name: "p"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("p.corrupt.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("p.json").path))
    }

    func testSchemaMismatchIsQuarantined() {
        let store = InMemoryDocumentStore()
        let old = #"{"schemaVersion": 0, "savedAt": "2026-01-01T00:00:00Z", "value": {"name": "x", "date": "2026-01-01T00:00:00Z"}}"#
        store.writeRaw(Data(old.utf8), name: "p")
        XCTAssertNil(store.load(Payload.self, name: "p"))
        XCTAssertEqual(store.quarantined, ["p"])
    }

    func testPhotoURLsSurviveAChangedContainerPath() throws {
        let before = URLRebaser(bundlePrefix: "file:///private/var/OLD/MyApp.app/", documentsPrefix: "file:///private/var/OLD/Documents/")
        let after = URLRebaser(bundlePrefix: "file:///private/var/NEW/MyApp.app/", documentsPrefix: "file:///private/var/NEW/Documents/")
        let store = InMemoryDocumentStore(codec: PersistenceCodec(rebaser: before))
        try store.save(Payload(name: "n", photo: URL(string: "file:///private/var/OLD/MyApp.app/before_river.jpg"),
                               date: Date(timeIntervalSince1970: 0)), name: "p")

        // Same bytes read by an install whose container moved.
        let moved = InMemoryDocumentStore(codec: PersistenceCodec(rebaser: after))
        let raw = try XCTUnwrap(rawData(store, name: "p"))
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("OLD"), "no absolute path is stored")
        moved.writeRaw(raw, name: "p")
        XCTAssertEqual(moved.load(Payload.self, name: "p")?.photo?.absoluteString, "file:///private/var/NEW/MyApp.app/before_river.jpg")

        try moved.save(Payload(name: "d", photo: URL(string: "file:///private/var/NEW/Documents/SpotPhotos/a.jpg"), date: Date(timeIntervalSince1970: 0)), name: "q")
        let restored = moved.load(Payload.self, name: "q")
        XCTAssertEqual(restored?.photo?.absoluteString, "file:///private/var/NEW/Documents/SpotPhotos/a.jpg")
    }

    /// Reads back the stored bytes through the codec of the same store (encode → decode is the public surface).
    private func rawData(_ store: InMemoryDocumentStore, name: String) -> Data? {
        let mirror = Mirror(reflecting: store).children.first { $0.label == "files" }?.value as? [String: Data]
        return mirror?[name]
    }
}

// MARK: - Deterministic seeds & refresher

final class SeedTests: XCTestCase {
    func testSeedIDsAreStableAcrossCalls() {
        XCTAssertEqual(Fixtures.seedCleanUps().map(\.id), Fixtures.seedCleanUps().map(\.id))
        XCTAssertEqual(Fixtures.seedActivities().map(\.id), Fixtures.seedActivities().map(\.id))
        XCTAssertEqual(Fixtures.seedFeedPosts().map(\.activityId), Fixtures.seedFeedPosts().map(\.activityId))
        XCTAssertEqual(Set(Fixtures.seedCleanUps().map(\.id)).count, Fixtures.seedCleanUps().count)
    }

    func testEverySeedNotificationPointsAtARealRecord() {
        let bundle = SeedData.make()
        let activityIDs = Set(bundle.activities.map(\.id) + bundle.feedPosts.map(\.activityId))
        let cleanUpIDs = Set(bundle.cleanUps.map(\.id))
        let commentIDs = Set(bundle.comments.map(\.id))
        for item in bundle.notifications {
            switch item.target {
            case .activity(let id): XCTAssertTrue(activityIDs.contains(id), item.subject)
            case .cleanUp(let id): XCTAssertTrue(cleanUpIDs.contains(id), item.subject)
            }
            if let commentID = item.commentID { XCTAssertTrue(commentIDs.contains(commentID), item.subject) }
        }
        XCTAssertTrue(bundle.comments.allSatisfy { c in activityIDs.contains(c.targetId) })
    }

    func testRefresherMovesStaleSeedEventsForwardByWholeWeeksOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        var stale = try XCTUnwrap(Fixtures.seedCleanUps().first { $0.status == .scheduled })
        stale.startsAt = calendar.date(byAdding: .day, value: -10, to: now)
        stale.attendeeIds = [User.demo.id, Fixtures.hostA.id]
        var done = try XCTUnwrap(Fixtures.seedCleanUps().first { $0.status == .done })
        let doneDate = done.startsAt
        done.startsAt = doneDate
        var userMade = stale
        userMade.id = UUID()   // not a seed id: never touched

        let result = SeedRefresher.refreshed([stale, done, userMade], now: now, calendar: calendar)
        let moved = try XCTUnwrap(result[0].startsAt)
        XCTAssertGreaterThanOrEqual(moved, calendar.startOfDay(for: now))
        XCTAssertEqual(calendar.component(.weekday, from: moved), calendar.component(.weekday, from: try XCTUnwrap(stale.startsAt)), "shifted by whole weeks")
        XCTAssertEqual(result[0].attendeeIds, stale.attendeeIds, "user state is preserved")
        XCTAssertEqual(result[1].startsAt, doneDate, "finished clean-ups stay in the past")
        XCTAssertEqual(result[2].startsAt, userMade.startsAt, "user-created clean-ups are untouched")
    }
}

// MARK: - Backend persistence ("restart")

final class BackendPersistenceTests: XCTestCase {
    private func makeBackend(_ store: DocumentStore) -> FakeBackendService {
        FakeBackendService(store: store, persistDelay: .zero, latency: 0...0)
    }

    private func makeActivity(title: String = "Brand new activity") -> Activity {
        Activity(id: UUID(), userId: User.demo.id, cleanUpId: nil, startedAt: Date(), endedAt: Date().addingTimeInterval(1800),
                 route: [], distance: 2500, duration: 1800, elevation: 5, kcal: 150, avgHR: nil, steps: 3000,
                 impactLog: ImpactLog(bags: 2, kg: 3), afterPhotoURL: DemoPhotos.url("after_path"), reelURL: nil,
                 title: title, kcalIsEstimated: true, healthWorkoutId: nil, beforePhotoURL: DemoPhotos.url("before_street"))
    }

    func testDataSurvivesARestart() async throws {
        let store = InMemoryDocumentStore()
        let first = makeBackend(store)
        let activity = makeActivity()
        try await first.upload(activity)

        let cleanUps = try await first.all()
        let target = try XCTUnwrap(cleanUps.first { !$0.attendeeIds.contains(Fixtures.hostF.id) && !$0.isFull && $0.status != .done })
        try await first.setRSVP(cleanUpId: target.id, userId: Fixtures.hostF.id, joining: true)

        // "Relaunch": a brand-new service on the same store.
        let second = makeBackend(store)
        let history = try await second.history(userId: User.demo.id)
        XCTAssertEqual(history.first?.id, activity.id, "newest activity first")
        XCTAssertEqual(history.first?.title, "Brand new activity")
        XCTAssertEqual(history.first?.afterPhotoURL?.lastPathComponent, "after_path.jpg")
        let reloaded = try await second.cleanUp(id: target.id)
        XCTAssertTrue(reloaded?.attendeeIds.contains(Fixtures.hostF.id) == true)
        let seededCount = SeedData.make().activities.count
        XCTAssertEqual(history.count, seededCount + 1)
    }

    func testCommentsBoostsAndPublishedPostsSurviveARestart() async throws {
        let store = InMemoryDocumentStore()
        let first = makeBackend(store)
        let activity = makeActivity()
        try await first.upload(activity)
        let allCleanUps = try await first.all()
        let cleanUp = try XCTUnwrap(allCleanUps.first)
        await first.publish(activity: activity, cleanUp: cleanUp, author: User.demo)
        _ = try await first.addComment(text: "  hello world  ", on: activity.id, by: User.demo)
        let summary = await first.toggleBoost(on: activity.id, by: Fixtures.hostA)
        XCTAssertEqual(summary.count, 1)

        let second = makeBackend(store)
        let comments = await second.comments(for: activity.id)
        XCTAssertEqual(comments.map(\.text), ["hello world"], "trimmed and persisted")
        let after = await second.boostSummary(for: activity.id, userId: Fixtures.hostA.id)
        XCTAssertTrue(after.isBoostedByMe)
        XCTAssertEqual(after.names, [Fixtures.hostA.name])
        let posts = try await second.recentPosts()
        XCTAssertEqual(posts.first?.activityId, activity.id)
    }

    func testEmptyOrTooLongCommentsAreRejected() async {
        let backend = makeBackend(InMemoryDocumentStore())
        do {
            _ = try await backend.addComment(text: "   ", on: SeedIDs.activity(1), by: User.demo)
            XCTFail("empty comment must throw")
        } catch {}
        do {
            _ = try await backend.addComment(text: String(repeating: "a", count: 301), on: SeedIDs.activity(1), by: User.demo)
            XCTFail("301 chars must throw")
        } catch {}
    }

    func testKudosOnFeedAndBoostOnPostAgree() async throws {
        let backend = makeBackend(InMemoryDocumentStore())
        let posts = try await backend.recentPosts()
        let post = try XCTUnwrap(posts.first { !$0.kudosGivenByMe })
        let updated = try await backend.toggleKudos(postId: post.id, userId: User.demo.id)
        XCTAssertEqual(updated.kudosCount, post.kudosCount + 1)
        let summary = await backend.boostSummary(for: post.activityId, userId: User.demo.id)
        XCTAssertEqual(summary.count, updated.kudosCount)
        XCTAssertTrue(summary.isBoostedByMe)
    }

    func testResetGoesBackToSeed() async throws {
        let store = InMemoryDocumentStore()
        let backend = makeBackend(store)
        try await backend.upload(makeActivity())
        await backend.resetToSeed()
        let history = try await backend.history(userId: User.demo.id)
        XCTAssertEqual(history.count, SeedData.make().activities.count)
        let reopened = makeBackend(store)
        let again = try await reopened.history(userId: User.demo.id)
        XCTAssertEqual(again.count, history.count, "reset is persisted")
    }

    func testActivityStreamEmitsNewActivities() async throws {
        let backend = makeBackend(InMemoryDocumentStore())
        var iterator = backend.changes(userId: User.demo.id).makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial?.count, SeedData.make().activities.count)
        try await backend.upload(makeActivity(title: "Streamed"))
        let updated = await iterator.next()
        XCTAssertEqual(updated?.first?.title, "Streamed")
    }
}

// MARK: - Session & inbox persistence

@MainActor
final class SessionAndInboxPersistenceTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "heal-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testSessionIsRestoredAndSignOutClearsIt() async {
        let defaults = freshDefaults()
        let session = AppSession(defaults: defaults)
        XCTAssertNil(session.currentUser)
        await session.signInWithApple()
        XCTAssertEqual(session.currentUser?.id, User.demo.id)

        let relaunched = AppSession(defaults: defaults)
        XCTAssertEqual(relaunched.currentUser?.id, User.demo.id, "still signed in after relaunch")
        relaunched.setNotificationsEnabled(false)
        XCTAssertFalse(AppSession(defaults: defaults).notificationsEnabled)

        await relaunched.signOut()
        XCTAssertNil(AppSession(defaults: defaults).currentUser)
    }

    func testInboxReadStateAndNewNotificationsSurviveARestart() async {
        let store = InMemoryDocumentStore()
        let first = FakeInboxService(store: store, latency: 0...0)
        let all = await first.notifications()
        let unreadBefore = await first.unreadCount()
        await first.markRead(id: all[0].id)
        await first.add(AppNotification(kind: .comment, target: .activity(SeedIDs.activity(1)), commentID: nil, actorName: "New",
                                        subject: "x", createdAt: Date(), isRead: false))

        let second = FakeInboxService(store: store, latency: 0...0)
        let reloaded = await second.notifications()
        XCTAssertEqual(reloaded.count, all.count + 1)
        XCTAssertEqual(reloaded.first?.actorName, "New", "newest first")
        let unreadAfter = await second.unreadCount()
        XCTAssertEqual(unreadAfter, unreadBefore)   // one read, one new unread
    }

    func testProfileViewModelShowsANewActivityThroughTheStream() async throws {
        let backend = FakeBackendService(store: InMemoryDocumentStore(), latency: 0...0)
        let vm = ProfileViewModel(user: User.demo, activities: backend)
        await vm.load()
        let before = vm.history.count
        let subscription = Task { await vm.subscribe() }
        try await Task.sleep(for: .milliseconds(100))

        let activity = Activity(id: UUID(), userId: User.demo.id, cleanUpId: nil, startedAt: Date(), endedAt: Date(),
                                route: [], distance: 1000, duration: 600, elevation: 0, kcal: 60, avgHR: nil, steps: 1200,
                                impactLog: ImpactLog(bags: 1), afterPhotoURL: nil, reelURL: nil, title: "Live update")
        try await backend.upload(activity)
        try await Task.sleep(for: .milliseconds(200))
        subscription.cancel()

        XCTAssertEqual(vm.history.count, before + 1)
        XCTAssertEqual(vm.rows.first?.title, "Live update")
    }

    func testResetDemoDataRestoresTheSeed() async throws {
        let backend = FakeBackendService(store: InMemoryDocumentStore(), latency: 0...0)
        let vm = ProfileViewModel(user: User.demo, activities: backend, resetter: DemoDataResetter(targets: [backend]))
        try await backend.upload(Activity(id: UUID(), userId: User.demo.id, cleanUpId: nil, startedAt: Date(), endedAt: Date(),
                                          route: [], distance: 1, duration: 1, elevation: 0, kcal: 0, avgHR: nil, steps: 0,
                                          impactLog: ImpactLog(), afterPhotoURL: nil, reelURL: nil, title: "Temp"))
        await vm.load()
        XCTAssertTrue(vm.rows.contains { $0.title == "Temp" })
        await vm.resetDemoData()
        XCTAssertFalse(vm.rows.contains { $0.title == "Temp" })
        XCTAssertEqual(vm.history.count, SeedData.make().activities.count)
    }
}
