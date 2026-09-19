import XCTest
@testable import MyApp

@MainActor
final class HomeAndCleanUpsViewModelTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    // Streak

    func testStreakIsZeroWithNoActivities() {
        XCTAssertEqual(HomeViewModel.weeklyStreak(activityDates: [], now: date("2026-09-19T10:00:00Z"), calendar: calendar), 0)
    }

    func testStreakCountsConsecutiveWeeksIncludingThisOne() {
        let dates = ["2026-09-18T10:00:00Z", "2026-09-10T10:00:00Z", "2026-09-02T10:00:00Z"].map(date)
        XCTAssertEqual(HomeViewModel.weeklyStreak(activityDates: dates, now: date("2026-09-19T10:00:00Z"), calendar: calendar), 3)
    }

    func testStreakSurvivesAnEmptyCurrentWeek() {
        let dates = ["2026-09-10T10:00:00Z", "2026-09-02T10:00:00Z"].map(date)
        XCTAssertEqual(HomeViewModel.weeklyStreak(activityDates: dates, now: date("2026-09-14T10:00:00Z"), calendar: calendar), 2)
    }

    func testStreakBreaksOnAGap() {
        let dates = ["2026-09-18T10:00:00Z", "2026-08-20T10:00:00Z"].map(date)
        XCTAssertEqual(HomeViewModel.weeklyStreak(activityDates: dates, now: date("2026-09-19T10:00:00Z"), calendar: calendar), 1)
    }

    // Home

    func testHomeLoadsPostsAndSortsNearbyByDistance() async {
        let backend = FakeBackendService()
        let vm = HomeViewModel(user: Fixtures.hostA, feed: backend, cleanUps: backend, activities: backend)
        await vm.load()
        XCTAssertFalse(vm.posts.isEmpty)
        XCTAssertFalse(vm.nearbyCleanUps.isEmpty)
        XCTAssertTrue(vm.nearbyCleanUps.allSatisfy { $0.status != .done })
        let distances = vm.nearbyCleanUps.map { Fixtures.homeCoordinate.distance(to: $0.coordinate) }
        XCTAssertEqual(distances, distances.sorted())
    }

    func testHomeRSVPToggles() async throws {
        let backend = FakeBackendService()
        let user = Fixtures.demoUsers[2]
        let vm = HomeViewModel(user: user, feed: backend, cleanUps: backend, activities: backend)
        await vm.load()
        let target = try XCTUnwrap(vm.nearbyCleanUps.first { !$0.attendeeIds.contains(user.id) && !$0.isFull })
        XCTAssertFalse(vm.isAttending(target))
        await vm.toggleRSVP(target)
        let updated = try XCTUnwrap(vm.nearbyCleanUps.first { $0.id == target.id })
        XCTAssertTrue(vm.isAttending(updated))
        XCTAssertEqual(vm.rsvpTitle(for: updated), "Going")
    }

    // Clean-Ups tab

    func testCleanUpsSegmentsPartitionTheList() async {
        let backend = FakeBackendService()
        let user = Fixtures.hostA
        let vm = CleanUpsViewModel(userId: user.id, repository: backend)
        await vm.load()
        let upcoming = vm.items(for: .upcoming), near = vm.items(for: .nearYou), done = vm.items(for: .done)
        XCTAssertTrue(upcoming.allSatisfy { $0.attendeeIds.contains(user.id) && $0.status != .done })
        XCTAssertTrue(near.allSatisfy { !$0.attendeeIds.contains(user.id) && $0.status != .done })
        XCTAssertTrue(done.allSatisfy { $0.status == .done })
        XCTAssertEqual(upcoming.count + near.count + done.count, vm.all.count)
    }
}

@MainActor
final class CleanUpCalendarTests: XCTestCase {
    func testUpcomingIsPopulatedFromFakeDataAndCalendarHasDots() async {
        let backend = FakeBackendService()
        let vm = CleanUpsViewModel(userId: User.demo.id, repository: backend)
        await vm.load()
        XCTAssertGreaterThanOrEqual(vm.items(for: .upcoming).count, 3)
        XCTAssertEqual(vm.calendarDays.count, 14)
        XCTAssertTrue(vm.calendarDays.contains { $0.eventCount > 0 })
    }

    func testSelectingADayFiltersAndTogglesOff() async throws {
        let backend = FakeBackendService()
        let vm = CleanUpsViewModel(userId: User.demo.id, repository: backend)
        await vm.load()
        let day = try XCTUnwrap(vm.calendarDays.first { $0.eventCount > 0 })
        let all = vm.items.count
        vm.selectDay(day.date)
        XCTAssertEqual(vm.items.count, day.eventCount)
        vm.selectDay(day.date)
        XCTAssertEqual(vm.items.count, all)
    }

    func testFakeSeedsHaveRealPhotos() {
        XCTAssertTrue(Fixtures.seedCleanUps().allSatisfy { $0.beforePhotoURL != nil })
        XCTAssertTrue(Fixtures.seedFeedPosts().allSatisfy { $0.beforePhotoURL != nil && $0.afterPhotoURL != nil })
        XCTAssertGreaterThanOrEqual(Fixtures.seedActivities().count, 6)
    }
}
