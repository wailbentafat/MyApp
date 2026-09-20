import XCTest
@testable import MyApp

@MainActor
final class PostDetailViewModelTests: XCTestCase {
    private func makeBackend() -> FakeBackendService {
        FakeBackendService(store: InMemoryDocumentStore(), persistDelay: .zero, latency: 0...0)
    }

    private func makeViewModel(_ backend: FakeBackendService, activityId: UUID, highlight: UUID? = nil,
                               user: User = User.demo) -> PostDetailViewModel {
        PostDetailViewModel(activityId: activityId, highlightCommentID: highlight, user: user,
                            activities: backend, feed: backend, social: backend)
    }

    // Resolution

    func testResolvesMyOwnActivity() async throws {
        let backend = makeBackend()
        let vm = makeViewModel(backend, activityId: SeedIDs.activity(1))
        await vm.load()
        let detail = try XCTUnwrap(vm.detail)
        XCTAssertTrue(detail.isMine)
        XCTAssertEqual(detail.title, "Morning Clean-Up")
        XCTAssertEqual(detail.media.map(\.id), ["before", "after", "route"])
        XCTAssertEqual(detail.stats.map(\.label), ["Distance", "Time", "Bags"])
        XCTAssertFalse(vm.isLoading)
    }

    func testResolvesACommunityPostFromTheFeed() async throws {
        let backend = makeBackend()
        let vm = makeViewModel(backend, activityId: SeedIDs.feedActivity(1))
        await vm.load()
        let detail = try XCTUnwrap(vm.detail)
        XCTAssertFalse(detail.isMine)
        XCTAssertEqual(detail.authorName, Fixtures.hostB.name)
        XCTAssertEqual(detail.media.map(\.id), ["before", "after"])
        XCTAssertEqual(detail.activity.id, SeedIDs.feedActivity(1), "share preview gets an activity")
    }

    func testUnknownPostIsReportedNotFound() async {
        let vm = makeViewModel(makeBackend(), activityId: UUID())
        await vm.load()
        XCTAssertNil(vm.detail)
        XCTAssertTrue(vm.notFound)
    }

    // Comments

    func testNotifiedCommentIsHighlightedAndCommentsAreOldestFirst() async {
        let vm = makeViewModel(makeBackend(), activityId: SeedIDs.activity(1), highlight: SeedIDs.comment(1))
        await vm.load()
        XCTAssertEqual(vm.highlightedCommentID, SeedIDs.comment(1))
        XCTAssertEqual(vm.comments.map(\.createdAt), vm.comments.map(\.createdAt).sorted())
        vm.clearHighlight()
        XCTAssertNil(vm.highlightedCommentID)
    }

    func testMissingHighlightTargetIsIgnored() async {
        let vm = makeViewModel(makeBackend(), activityId: SeedIDs.activity(1), highlight: UUID())
        await vm.load()
        XCTAssertNil(vm.highlightedCommentID)
    }

    func testSendingACommentTrimsClearsTheDraftAndPersists() async throws {
        let backend = makeBackend()
        let vm = makeViewModel(backend, activityId: SeedIDs.activity(1))
        await vm.load()
        let before = vm.comments.count

        vm.draft = "   "
        XCTAssertFalse(vm.canSend)
        vm.draft = "  Thanks everyone!  "
        XCTAssertTrue(vm.canSend)
        await vm.sendComment()

        XCTAssertEqual(vm.comments.count, before + 1)
        XCTAssertEqual(vm.comments.last?.text, "Thanks everyone!")
        XCTAssertTrue(vm.isMine(try XCTUnwrap(vm.comments.last)))
        XCTAssertEqual(vm.draft, "")
        let stored = await backend.comments(for: SeedIDs.activity(1))
        XCTAssertEqual(stored.count, before + 1)
    }

    func testCommentLengthLimit() {
        let vm = makeViewModel(makeBackend(), activityId: SeedIDs.activity(1))
        vm.draft = String(repeating: "a", count: PostDetailViewModel.maxCommentLength)
        XCTAssertTrue(vm.canSend)
        vm.draft += "a"
        XCTAssertFalse(vm.canSend)
    }

    // Eco-Boost

    func testBoostToggleUpdatesCountAndText() async {
        let backend = makeBackend()
        let vm = makeViewModel(backend, activityId: SeedIDs.activity(3))
        await vm.load()
        let start = vm.boost.count
        XCTAssertFalse(vm.boost.isBoostedByMe)
        XCTAssertEqual(vm.boostButtonTitle, "Eco-Boost")

        await vm.toggleBoost()
        XCTAssertTrue(vm.boost.isBoostedByMe)
        XCTAssertEqual(vm.boost.count, start + 1)
        XCTAssertEqual(vm.boostButtonTitle, "Boosted")

        await vm.toggleBoost()
        XCTAssertFalse(vm.boost.isBoostedByMe)
        XCTAssertEqual(vm.boost.count, start)
    }

    func testBoostersText() async {
        let vm = makeViewModel(makeBackend(), activityId: SeedIDs.feedActivity(1))
        await vm.load()
        XCTAssertTrue(vm.boostersText.hasSuffix("gave Eco-Boost"))
        XCTAssertTrue(vm.boostersText.contains("others"), vm.boostersText)

        let empty = makeViewModel(makeBackend(), activityId: UUID())
        XCTAssertEqual(empty.boostersText, "Be the first to give an Eco-Boost")
    }
}

// MARK: - Notification navigation & simulated reactions

@MainActor
final class NotificationNavigationTests: XCTestCase {
    func testTappingEachKindLeadsToTheRightDestinationAndMarksItRead() async throws {
        let inbox = FakeInboxService(store: InMemoryDocumentStore(), latency: 0...0)
        let vm = NotificationsViewModel(inbox: inbox)
        await vm.load()

        let like = try XCTUnwrap(vm.all.first { $0.kind == .activityLike && !$0.isRead })
        let destination = await vm.open(like)
        XCTAssertEqual(destination, .post(activityId: like.targetActivityID!, highlightCommentID: nil))
        XCTAssertTrue(vm.all.first { $0.id == like.id }?.isRead == true)

        let comment = try XCTUnwrap(vm.all.first { $0.kind == .comment })
        XCTAssertEqual(vm.destination(for: comment), .post(activityId: comment.targetActivityID!, highlightCommentID: comment.commentID))
        XCTAssertNotNil(comment.commentID)

        let community = try XCTUnwrap(vm.all.first { $0.kind == .communityLike })
        if case .cleanUp(let id) = vm.destination(for: community) {
            XCTAssertTrue(SeedData.make().cleanUps.contains { $0.id == id })
        } else {
            XCTFail("community likes open the Clean-Up")
        }
    }

    func testNotificationsScreenUpdatesLiveWhenSomethingArrives() async throws {
        let inbox = FakeInboxService(store: InMemoryDocumentStore(), latency: 0...0)
        let vm = NotificationsViewModel(inbox: inbox)
        let subscription = Task { await vm.subscribe() }
        try await Task.sleep(for: .milliseconds(100))
        let count = vm.all.count
        await inbox.add(AppNotification(kind: .activityLike, target: .activity(SeedIDs.activity(1)), commentID: nil,
                                        actorName: "Live", subject: "x", createdAt: Date(), isRead: false))
        try await Task.sleep(for: .milliseconds(150))
        subscription.cancel()
        XCTAssertEqual(vm.all.count, count + 1)
        XCTAssertEqual(vm.all.first?.actorName, "Live")
    }

    func testSimulatedReactionsCreateNotificationsThatResolveToAPost() async throws {
        let backend = FakeBackendService(store: InMemoryDocumentStore(), latency: 0...0)
        let inbox = FakeInboxService(store: InMemoryDocumentStore(), seed: [], latency: 0...0)
        let simulator = ReactionSimulator(backend: backend, inbox: inbox, delays: [.zero, .zero, .zero])
        let activity = Activity(id: UUID(), userId: User.demo.id, cleanUpId: nil, startedAt: Date(), endedAt: Date(),
                                route: [], distance: 2000, duration: 900, elevation: 0, kcal: 90, avgHR: nil, steps: 2500,
                                impactLog: ImpactLog(bags: 2), afterPhotoURL: nil, reelURL: nil, title: "Fresh")
        try await backend.upload(activity)
        await simulator.react(to: activity)

        let items = await inbox.notifications()
        XCTAssertEqual(Set(items.map(\.kind)), Set(NotificationKind.allCases))
        let comment = try XCTUnwrap(items.first { $0.kind == .comment })
        let vm = PostDetailViewModel(activityId: activity.id, highlightCommentID: comment.commentID, user: User.demo,
                                     activities: backend, feed: backend, social: backend)
        await vm.load()
        XCTAssertEqual(vm.detail?.title, "Fresh")
        XCTAssertEqual(vm.highlightedCommentID, comment.commentID)
        XCTAssertTrue(vm.boost.count >= 2)
    }

    func testUploadHookTriggersTheSimulator() async throws {
        let backend = FakeBackendService(store: InMemoryDocumentStore(), latency: 0...0)
        let inbox = FakeInboxService(store: InMemoryDocumentStore(), seed: [], latency: 0...0)
        let simulator = ReactionSimulator(backend: backend, inbox: inbox, delays: [.zero, .zero, .zero])
        await backend.setUploadHook { activity in await simulator.react(to: activity) }
        try await backend.upload(Activity(id: UUID(), userId: User.demo.id, cleanUpId: nil, startedAt: Date(), endedAt: Date(),
                                          route: [], distance: 1, duration: 1, elevation: 0, kcal: 0, avgHR: nil, steps: 0,
                                          impactLog: ImpactLog(), afterPhotoURL: nil, reelURL: nil, title: "Hooked"))
        try await Task.sleep(for: .milliseconds(300))
        let count = await inbox.notifications().count
        XCTAssertEqual(count, 3)
    }
}

private extension AppNotification {
    var targetActivityID: UUID? {
        if case .activity(let id) = target { id } else { nil }
    }
}
