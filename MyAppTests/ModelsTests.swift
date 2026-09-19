import XCTest
@testable import MyApp

final class ModelsTests: XCTestCase {
    func testImpactLogRoundTripsThroughJSON() throws {
        let log = ImpactLog(bags: 2, kg: 5.5, items: [.plastic: 12, .glass: 3])
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(ImpactLog.self, from: data)
        XCTAssertEqual(decoded, log)
        XCTAssertEqual(decoded.totalItems, 15)
    }

    func testEmptyImpactLog() {
        XCTAssertTrue(ImpactLog().isEmpty)
        XCTAssertFalse(ImpactLog(bags: 1).isEmpty)
    }

    func testMockRepositoryCompletesCleanUp() async throws {
        let cleanUp = CleanUp(title: "Park corner", latitude: 36.7, longitude: 3.05)
        let repo = MockCleanUpRepository(seed: [cleanUp])
        let activityId = UUID()
        try await repo.complete(cleanUpId: cleanUp.id, activityId: activityId)
        let updated = try await repo.cleanUp(id: cleanUp.id)
        XCTAssertEqual(updated?.status, .done)
    }
}
