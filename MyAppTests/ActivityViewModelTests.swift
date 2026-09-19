import CoreLocation
import XCTest
@testable import MyApp

// MARK: - Test doubles

@MainActor
private final class StubLocation: LocationProviding {
    func requestAuthorization() {}
    func startUpdates() -> AsyncStream<CLLocation> { AsyncStream { _ in } }
    func stopUpdates() {}
}

@MainActor
private final class StubHealth: HealthProviding {
    var savedWorkouts = 0
    func requestAuthorization() async -> Bool { true }
    func bodyMassKg() async -> Double? { 70 }
    func heartRateUpdates() -> AsyncStream<Int> { AsyncStream { _ in } }
    func stepUpdates(from start: Date) -> AsyncStream<Int> { AsyncStream { _ in } }
    func saveWorkout(_ activity: Activity) async throws -> UUID? { savedWorkouts += 1; return UUID() }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }
}

// MARK: - Tests

@MainActor
final class ActivityViewModelTests: XCTestCase {
    private var clock = Clock()
    private var activities = MockActivityRepository()
    private var cleanUps = MockCleanUpRepository()
    private var health = StubHealth()

    override func setUp() async throws {
        clock = Clock()
        activities = MockActivityRepository()
        cleanUps = MockCleanUpRepository()
        health = StubHealth()
    }

    private func makeViewModel(context: ActivityContext = .free) -> ActivityViewModel {
        let clock = clock
        return ActivityViewModel(
            context: context, location: StubLocation(), health: health,
            activities: activities, cleanUps: cleanUps, now: { clock.date }
        )
    }

    /// ~11.1 m per 0.0001° of latitude.
    private func fix(_ latSteps: Double, altitude: Double = 0, accuracy: Double = 5, at seconds: TimeInterval) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 36.7 + latSteps * 0.0001, longitude: 3.0),
            altitude: altitude, horizontalAccuracy: accuracy, verticalAccuracy: 5,
            course: -1, speed: -1, timestamp: clock.date.addingTimeInterval(seconds)
        )
    }

    // State machine

    func testStartMovesToRecording() {
        let vm = makeViewModel()
        vm.start()
        XCTAssertEqual(vm.state, .running)
        XCTAssertEqual(vm.screen, .recording)
    }

    func testPauseFreezesTimeAndResumeContinues() {
        let vm = makeViewModel()
        vm.start()
        clock.advance(10); vm.tick()
        XCTAssertEqual(vm.elapsed, 10, accuracy: 0.01)

        vm.pause()
        clock.advance(60); vm.tick()
        XCTAssertEqual(vm.elapsed, 10, accuracy: 0.01)

        vm.resume()
        clock.advance(5); vm.tick()
        XCTAssertEqual(vm.elapsed, 15, accuracy: 0.01)
    }

    func testFinishMovesToImpactLog() {
        let vm = makeViewModel()
        vm.start()
        clock.advance(30)
        vm.finish()
        XCTAssertEqual(vm.state, .finished)
        XCTAssertEqual(vm.screen, .impactLog)
        XCTAssertEqual(vm.elapsed, 30, accuracy: 0.01)
    }

    // GPS handling

    func testDistanceAccumulates() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.handle(fix(1, at: 5))     // ≈ 11 m
        vm.handle(fix(2, at: 10))    // ≈ 11 m
        XCTAssertEqual(vm.distanceMeters, 22.2, accuracy: 1)
        XCTAssertEqual(vm.route.count, 3)
    }

    func testInaccurateFixesAreIgnored() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.handle(fix(1, accuracy: 80, at: 5))
        vm.handle(fix(1, accuracy: -1, at: 6))
        XCTAssertEqual(vm.distanceMeters, 0)
        XCTAssertEqual(vm.route.count, 1)
    }

    func testImpossibleSpeedJumpIsIgnored() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.handle(fix(100, at: 1))   // ≈ 1.1 km in 1 s
        XCTAssertEqual(vm.distanceMeters, 0)
    }

    func testGPSJitterIsIgnored() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.handle(fix(0.05, at: 1))  // ≈ 0.5 m
        XCTAssertEqual(vm.distanceMeters, 0)
    }

    func testLocationsIgnoredWhilePausedAndGapNotCounted() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.pause()
        vm.handle(fix(1, at: 5))
        XCTAssertEqual(vm.distanceMeters, 0)

        clock.advance(600)
        vm.resume()
        vm.handle(fix(50, at: 600))  // first fix after resume: new anchor, no jump counted
        vm.handle(fix(51, at: 605))
        XCTAssertEqual(vm.distanceMeters, 11.1, accuracy: 1)
    }

    func testCaloriesGrowWithMovement() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, at: 0))
        vm.handle(fix(2, at: 10))    // ≈ 22 m in 10 s → 2.2 m/s
        XCTAssertGreaterThan(vm.kcal, 0)
        XCTAssertEqual(vm.kcalSource, .estimated)
    }

    func testElevationGainIgnoresNoiseAndDescents() {
        let vm = makeViewModel()
        vm.start()
        vm.handle(fix(0, altitude: 10, at: 0))
        vm.handle(fix(1, altitude: 11, at: 5))    // +1 m: noise
        vm.handle(fix(2, altitude: 15, at: 10))   // +5 m from anchor
        vm.handle(fix(3, altitude: 8, at: 15))    // descent
        XCTAssertEqual(vm.elevationGain, 5, accuracy: 0.01)
    }

    // Impact log

    func testBagCounterNeverGoesNegative() {
        let vm = makeViewModel()
        vm.removeBag()
        XCTAssertEqual(vm.impact.bags, 0)
        vm.addBag(); vm.addBag(); vm.removeBag()
        XCTAssertEqual(vm.impact.bags, 1)
    }

    func testItemCountersAndWeight() {
        let vm = makeViewModel()
        vm.increment(.plastic); vm.increment(.plastic)
        vm.decrement(.plastic)
        XCTAssertEqual(vm.impact.items[.plastic], 1)
        vm.decrement(.plastic); vm.decrement(.plastic)
        XCTAssertNil(vm.impact.items[.plastic])

        vm.adjustKg(by: 0.5); vm.adjustKg(by: 0.5)
        XCTAssertEqual(vm.impact.kg, 1.0, accuracy: 0.001)
        vm.adjustKg(by: -0.5); vm.adjustKg(by: -0.5); vm.adjustKg(by: -0.5)
        XCTAssertEqual(vm.impact.kg, 0)
    }

    // Formatting

    func testDurationFormatting() {
        XCTAssertEqual(ActivityViewModel.formatDuration(65), "01:05")
        XCTAssertEqual(ActivityViewModel.formatDuration(3725), "1:02:05")
        XCTAssertEqual(ActivityViewModel.formatDuration(-5), "00:00")
    }

    func testPaceFormatting() {
        XCTAssertEqual(ActivityViewModel.formatPace(speed: 0), "--:--")
        XCTAssertEqual(ActivityViewModel.formatPace(speed: 2.5), "6:40")
    }

    func testDefaultTitleUsesCleanUpTitle() {
        let cleanUp = CleanUp(title: "Park corner", latitude: 36.7, longitude: 3.0)
        XCTAssertEqual(makeViewModel(context: .cleanUp(cleanUp)).title, "Park corner")
        XCTAssertTrue(makeViewModel().title.hasSuffix("Clean-Up"))
    }

    // Saving

    func testSaveStoresActivitySavesWorkoutAndCompletesCleanUp() async throws {
        let cleanUp = CleanUp(title: "Park corner", latitude: 36.7, longitude: 3.0)
        cleanUps = MockCleanUpRepository(seed: [cleanUp])
        let vm = makeViewModel(context: .cleanUp(cleanUp))
        vm.start()
        vm.handle(fix(0, at: 0)); vm.handle(fix(2, at: 10))
        vm.addBag()
        clock.advance(10)
        vm.finish()

        await vm.save()

        XCTAssertEqual(vm.screen, .summary)
        let history = try await activities.history()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.cleanUpId, cleanUp.id)
        XCTAssertEqual(history.first?.impact.bags, 1)
        XCTAssertNotNil(history.first?.healthWorkoutId)
        XCTAssertEqual(health.savedWorkouts, 1)
        let updated = try await cleanUps.cleanUp(id: cleanUp.id)
        XCTAssertEqual(updated?.status, .done)
    }
}
