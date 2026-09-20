import XCTest
@testable import MyApp

@MainActor
private final class StubLocationFix: LocationFixing {
    var fix: (coordinate: Coordinate, heading: Double)?
    func requestWhenInUseAuthorization() {}
    func requestFix() async -> (coordinate: Coordinate, heading: Double)? { fix }
}

@MainActor
final class MapViewModelTests: XCTestCase {
    private func makeViewModel(location: StubLocationFix? = nil) -> MapViewModel {
        MapViewModel(repository: FakeBackendService(), location: location ?? StubLocationFix())
    }

    func testLoadShowsEveryCleanUpAndFilterNarrowsThem() async {
        let vm = makeViewModel()
        await vm.load()
        XCTAssertEqual(vm.visibleCleanUps.count, vm.cleanUps.count)
        XCTAssertFalse(vm.cleanUps.isEmpty)

        vm.select(.live)
        XCTAssertTrue(vm.visibleCleanUps.allSatisfy { $0.status == .live })
        XCTAssertEqual(vm.visibleCleanUps.count, vm.count(for: .live))
        XCTAssertTrue(vm.isSelected(.live))

        vm.select(nil)
        XCTAssertEqual(vm.visibleCleanUps.count, vm.cleanUps.count)
    }

    func testChipTitlesIncludeCounts() async {
        let vm = makeViewModel()
        await vm.load()
        XCTAssertEqual(vm.chipTitle(for: nil), "All \(vm.cleanUps.count)")
        XCTAssertEqual(MapViewModel.filters.count, CleanUpStatus.allCases.count + 1)
    }

    func testCenterOnMeMovesTheCameraOnlyWhenThereIsAFix() async {
        let location = StubLocationFix()
        let vm = makeViewModel(location: location)
        let initial = vm.target

        await vm.centerOnMe()
        XCTAssertEqual(vm.target, initial)

        location.fix = (Coordinate(latitude: 36.75, longitude: 3.06), 0)
        await vm.centerOnMe()
        XCTAssertEqual(vm.target.center, Coordinate(latitude: 36.75, longitude: 3.06))
        XCTAssertNotEqual(vm.target, initial)
    }

    func testBagsTextForMarker() async throws {
        let vm = makeViewModel()
        await vm.load()
        let cleanUp = try XCTUnwrap(vm.cleanUps.first)
        XCTAssertEqual(vm.bagsText(for: cleanUp), String(cleanUp.estimatedBags))
    }
}

@MainActor
final class CleanUpDetailViewModelTests: XCTestCase {
    private func makeViewModel(cleanUp: CleanUp, user: User, backend: FakeBackendService) -> CleanUpDetailViewModel {
        let completion = ActivityCompletionCoordinator(activities: backend, cleanUps: backend, feed: backend)
        return CleanUpDetailViewModel(cleanUp: cleanUp, user: user, repository: backend, completion: completion)
    }

    func testRSVPTogglesAttendanceAndTitle() async throws {
        let backend = FakeBackendService()
        let user = Fixtures.hostF
        let candidates = try await backend.all()
        let stored = try XCTUnwrap(candidates.first {
            !$0.attendeeIds.contains(user.id) && !$0.isFull && $0.status != .done
        })
        let vm = makeViewModel(cleanUp: stored, user: user, backend: backend)
        XCTAssertFalse(vm.isAttending)
        XCTAssertEqual(vm.rsvpTitle, "RSVP — I'm in")

        await vm.toggleRSVP()
        XCTAssertTrue(vm.isAttending)
        XCTAssertEqual(vm.rsvpTitle, "Leave Clean-Up")
        XCTAssertTrue(vm.canStartActivity)
    }

    func testDoneCleanUpCannotStartAnActivity() {
        let done = Fixtures.seedCleanUps().first { $0.status == .done }!
        let vm = makeViewModel(cleanUp: done, user: Fixtures.hostA, backend: FakeBackendService())
        XCTAssertTrue(vm.isDone)
        XCTAssertFalse(vm.canStartActivity)
    }

    func testGearChecklistCountsMyCommitment() throws {
        let cleanUp = try XCTUnwrap(Fixtures.seedCleanUps().first { !$0.gear.isEmpty })
        let item = cleanUp.gear[0]
        let vm = makeViewModel(cleanUp: cleanUp, user: Fixtures.hostA, backend: FakeBackendService())
        XCTAssertEqual(vm.bringingText(for: item), "\(item.committedCount) bringing")
        vm.toggleGear(item)
        XCTAssertTrue(vm.isCommitted(item))
        XCTAssertEqual(vm.bringingText(for: item), "\(item.committedCount + 1) bringing")
        vm.toggleGear(item)
        XCTAssertFalse(vm.isCommitted(item))
    }
}
