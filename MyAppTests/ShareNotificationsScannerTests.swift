import AVFoundation
import XCTest
@testable import MyApp

// MARK: - Notifications

@MainActor
final class NotificationsViewModelTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let now = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!

    private func makeViewModel(_ items: [AppNotification]) -> NotificationsViewModel {
        NotificationsViewModel(inbox: FakeInboxService(items: items), calendar: calendar, now: { [now] in now })
    }

    private func item(_ kind: NotificationKind, hoursAgo: Double, read: Bool = false, others: Int = 0) -> AppNotification {
        AppNotification(kind: kind, actorName: "Maya Chen", otherActorsCount: others, subject: "Riverside sweep",
                        commentText: kind == .comment ? "Nice!" : nil, photoURL: nil,
                        createdAt: now.addingTimeInterval(-hoursAgo * 3600), isRead: read)
    }

    func testSeedInboxHasAllThreeKindsAndUnread() {
        let items = Fixtures.seedNotifications()
        XCTAssertEqual(Set(items.map(\.kind)), Set(NotificationKind.allCases))
        XCTAssertTrue(items.contains { !$0.isRead })
    }

    func testSectionsGroupByDay() async {
        let vm = makeViewModel([item(.activityLike, hoursAgo: 1), item(.comment, hoursAgo: 20),
                                item(.communityLike, hoursAgo: 24 * 3), item(.activityLike, hoursAgo: 24 * 12)])
        await vm.load()
        XCTAssertEqual(vm.sections.map(\.title), ["Today", "Yesterday", "This week", "Earlier"])
    }

    func testFiltersNarrowTheList() async {
        let vm = makeViewModel([item(.activityLike, hoursAgo: 1), item(.comment, hoursAgo: 2), item(.communityLike, hoursAgo: 3)])
        await vm.load()
        XCTAssertEqual(vm.filtered.count, 3)
        vm.filter = .comments
        XCTAssertEqual(vm.filtered.map(\.kind), [.comment])
        vm.filter = .community
        XCTAssertEqual(vm.filtered.map(\.kind), [.communityLike])
    }

    func testMarkReadAndMarkAllRead() async {
        let first = item(.activityLike, hoursAgo: 1)
        let vm = makeViewModel([first, item(.comment, hoursAgo: 2)])
        await vm.load()
        XCTAssertEqual(vm.unreadCount, 2)
        await vm.open(first)
        XCTAssertEqual(vm.unreadCount, 1)
        await vm.markAllRead()
        XCTAssertEqual(vm.unreadCount, 0)
        XCTAssertFalse(vm.hasUnread)
    }

    func testRowText() {
        let vm = makeViewModel([])
        XCTAssertEqual(vm.actorText(for: item(.communityLike, hoursAgo: 1, others: 4)), "Maya Chen and 4 others")
        XCTAssertEqual(vm.actorText(for: item(.communityLike, hoursAgo: 1, others: 1)), "Maya Chen and 1 other")
        XCTAssertTrue(vm.actionText(for: item(.comment, hoursAgo: 1)).contains("commented"))
    }
}

// MARK: - Scanner camera

@MainActor
private final class StubCamera: CameraProviding {
    var isAvailable = true
    var authorization: CameraAuthorization = .authorized
    var previewSession: AVCaptureSession? { nil }
    var grantAccess = true
    private(set) var started = false
    private(set) var torch = false

    func requestAccess() async -> Bool { grantAccess }
    func start() async { started = true }
    func stop() {}
    func setTorch(_ on: Bool) { torch = on }
    func capturePhoto() async -> UIImage? { UIImage(systemName: "camera") }
}

@MainActor
final class CameraScannerViewModelTests: XCTestCase {
    func testSimulatorWithoutCameraUsesDemoModeAndStillCaptures() async {
        let camera = StubCamera()
        camera.isAvailable = false
        let vm = CameraScannerViewModel(camera: camera)
        await vm.start()
        XCTAssertEqual(vm.state, .demo)
        XCTAssertTrue(vm.canCapture)
        let image = await vm.capture()
        XCTAssertNotNil(image)
    }

    func testAuthorizedCameraStartsRunning() async {
        let camera = StubCamera()
        let vm = CameraScannerViewModel(camera: camera)
        await vm.start()
        XCTAssertEqual(vm.state, .running)
        XCTAssertTrue(camera.started)
        vm.toggleTorch()
        XCTAssertTrue(vm.torchOn)
        XCTAssertTrue(camera.torch)
        vm.toggleTorch()
        XCTAssertFalse(camera.torch)
    }

    func testPermissionFlow() async {
        let denied = StubCamera()
        denied.authorization = .denied
        let deniedVM = CameraScannerViewModel(camera: denied)
        await deniedVM.start()
        XCTAssertEqual(deniedVM.state, .denied)
        XCTAssertFalse(deniedVM.canCapture)
        let noImage = await deniedVM.capture()
        XCTAssertNil(noImage)

        let asked = StubCamera()
        asked.authorization = .notDetermined
        asked.grantAccess = false
        let askedVM = CameraScannerViewModel(camera: asked)
        await askedVM.start()
        XCTAssertEqual(askedVM.state, .denied)
    }

    func testHintsRotate() {
        let vm = CameraScannerViewModel(camera: StubCamera())
        let first = vm.hint
        vm.advanceHint()
        XCTAssertNotEqual(vm.hint, first)
    }

    func testTorchIgnoredWithoutLiveCamera() async {
        let camera = StubCamera()
        camera.isAvailable = false
        let vm = CameraScannerViewModel(camera: camera)
        await vm.start()
        vm.toggleTorch()
        XCTAssertFalse(vm.torchOn)
    }
}

// MARK: - Share

@MainActor
private final class StubSnapshotter: MapSnapshotting {
    var result: MapSnapshotResult?
    func snapshot(route: [Coordinate], size: CGSize) async -> MapSnapshotResult? { result }
}

@MainActor
private final class StubRenderer: StoryImageRendering {
    private(set) var rendered: [ShareCardModel.Kind] = []
    func render(_ card: ShareCardModel) -> UIImage? {
        rendered.append(card.kind)
        return UIImage(systemName: "star")
    }
}

@MainActor
private final class StubExporter: ImageExporting {
    var saveSucceeds = true
    private(set) var saved = 0
    private(set) var copied = 0
    func saveToPhotos(_ image: UIImage) async -> Bool { saved += 1; return saveSucceeds }
    func copy(_ image: UIImage) { copied += 1 }
}

@MainActor
private final class StubShare: ShareService {
    var outcome: ShareOutcome = .postedToInstagram
    private(set) var sharedImages = 0
    private(set) var captions: [String] = []
    func shareToInstagramStory(image: UIImage?, videoURL: URL?, caption: String) async -> ShareOutcome {
        if image != nil { sharedImages += 1 }
        captions.append(caption)
        return outcome
    }
}

@MainActor
final class ActivityShareViewModelTests: XCTestCase {
    private let snapshotter = StubSnapshotter()
    private let renderer = StubRenderer()
    private let exporter = StubExporter()
    private let share = StubShare()

    private func makeViewModel(_ activity: Activity, showsDone: Bool = false) -> ActivityShareViewModel {
        ActivityShareViewModel(activity: activity, showsDone: showsDone, snapshotter: snapshotter,
                               renderer: renderer, exporter: exporter, share: share)
    }

    func testSeededActivityGetsAllFourStoryCards() async throws {
        let activity = try XCTUnwrap(Fixtures.seedActivities().first { $0.beforePhotoURL != nil && $0.afterPhotoURL != nil })
        let vm = makeViewModel(activity)
        XCTAssertTrue(vm.isPreparing)
        await vm.prepare()
        XCTAssertFalse(vm.isPreparing)
        XCTAssertEqual(vm.cards.map(\.kind), [.route, .photo, .beforeAfter, .impact])
        XCTAssertFalse(vm.cards[0].routePoints.isEmpty)   // fallback projection without a map snapshot
        XCTAssertNotNil(vm.cards[1].photo)
        XCTAssertNotNil(vm.cards[2].beforePhoto)
        XCTAssertNotNil(vm.cards[2].afterPhoto)
        XCTAssertTrue(vm.cards[3].bottlesText.contains("plastic bottles"))
    }

    func testFreeActivityWithoutRouteOrBeforePhotoSkipsThoseCards() async throws {
        var activity = try XCTUnwrap(Fixtures.seedActivities().first)
        activity.route = []
        activity.beforePhotoURL = nil
        activity.afterPhotoURL = nil
        let vm = makeViewModel(activity)
        await vm.prepare()
        XCTAssertEqual(vm.cards.map(\.kind), [.photo, .impact])
        XCTAssertNotNil(vm.cards[0].photo, "photo card falls back to a demo photo, never empty")
    }

    func testMapSnapshotIsUsedWhenAvailable() async throws {
        let activity = try XCTUnwrap(Fixtures.seedActivities().first)
        snapshotter.result = MapSnapshotResult(image: UIImage(systemName: "map")!, normalizedPoints: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.5)])
        let vm = makeViewModel(activity)
        await vm.prepare()
        XCTAssertNotNil(vm.cards[0].mapImage)
        XCTAssertEqual(vm.cards[0].routePoints.count, 2)
    }

    func testSharingRendersTheSelectedCardAndCachesIt() async throws {
        let activity = try XCTUnwrap(Fixtures.seedActivities().first)
        let vm = makeViewModel(activity)
        await vm.prepare()
        vm.currentIndex = 1
        await vm.shareToInstagramStory()
        XCTAssertEqual(share.sharedImages, 1)
        XCTAssertTrue(share.captions[0].contains(activity.title))
        XCTAssertEqual(vm.toast, "Opened Instagram Stories")
        _ = vm.currentImage()
        XCTAssertEqual(renderer.rendered, [.photo], "rendered once, then cached")
    }

    func testSaveAndCopyReportTheResult() async throws {
        let vm = makeViewModel(try XCTUnwrap(Fixtures.seedActivities().first))
        await vm.prepare()
        await vm.saveToPhotos()
        XCTAssertEqual(exporter.saved, 1)
        XCTAssertEqual(vm.toast, "Saved to Photos")
        exporter.saveSucceeds = false
        await vm.saveToPhotos()
        XCTAssertNotEqual(vm.toast, "Saved to Photos")
        vm.copyImage()
        XCTAssertEqual(exporter.copied, 1)
        XCTAssertEqual(vm.toast, "Copied")
    }

    func testStatTexts() throws {
        var activity = try XCTUnwrap(Fixtures.seedActivities().first)
        activity.distance = 9410
        activity.duration = 2771
        let vm = makeViewModel(activity)
        XCTAssertEqual(vm.distanceText, "9.41 km")
        XCTAssertEqual(vm.timeText, "46:11")
        XCTAssertEqual(vm.paceText, "4:54 /km")
    }

    func testRouteProjectorFitsInsideTheRectNorthUp() {
        let route = [Coordinate(latitude: 36.70, longitude: 3.00), Coordinate(latitude: 36.71, longitude: 3.00),
                     Coordinate(latitude: 36.71, longitude: 3.02)]
        let rect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.4)
        let points = RouteProjector.normalize(route, in: rect)
        XCTAssertEqual(points.count, 3)
        XCTAssertTrue(points.allSatisfy { rect.insetBy(dx: -0.0001, dy: -0.0001).contains($0) })
        XCTAssertLessThan(points[1].y, points[0].y, "north is up")
        XCTAssertGreaterThan(points[2].x, points[1].x, "east is right")
    }

    func testRouteSimplifyLimitsPointCount() {
        let many = (0..<1000).map { CGPoint(x: Double($0) / 1000, y: 0.5) }
        XCTAssertEqual(RouteProjector.simplify(many, limit: 100).count, 100)
        XCTAssertEqual(RouteProjector.simplify(Array(many.prefix(10)), limit: 100).count, 10)
    }
}

// MARK: - Profile

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testEveryActivityIsListedWithAThumbnail() async {
        let backend = FakeBackendService()
        let vm = ProfileViewModel(user: User.demo, activities: backend)
        await vm.load()
        XCTAssertGreaterThanOrEqual(vm.rows.count, 6)
        XCTAssertTrue(vm.hasHistory)
        XCTAssertTrue(vm.rows.allSatisfy { $0.photoURL != nil })
        XCTAssertEqual(vm.rows.first?.activity.startedAt, vm.history.map(\.startedAt).max())
    }

    func testOpeningARowSelectsItsActivity() async throws {
        let backend = FakeBackendService()
        let vm = ProfileViewModel(user: User.demo, activities: backend)
        await vm.load()
        let row = try XCTUnwrap(vm.rows.first)
        vm.open(row)
        XCTAssertEqual(vm.selectedActivity?.id, row.activity.id)
        vm.closePreview()
        XCTAssertNil(vm.selectedActivity)
    }
}
