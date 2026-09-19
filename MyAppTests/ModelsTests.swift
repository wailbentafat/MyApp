import XCTest
@testable import MyApp

final class ModelsTests: XCTestCase {
    func testImpactLogRoundTripsThroughJSON() throws {
        var log = ImpactLog(bags: 2, kg: 5.5)
        log.itemCounts[WasteType.plastic.rawValue] = 12
        log.itemCounts[WasteType.glass.rawValue] = 3
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(ImpactLog.self, from: data)
        XCTAssertEqual(decoded, log)
        XCTAssertEqual(decoded.totalItems, 15)
        XCTAssertEqual(decoded.count(for: .plastic), 12)
        XCTAssertEqual(decoded.count(for: .metal), 0)
    }

    func testEmptyImpactLog() {
        XCTAssertTrue(ImpactLog().isEmpty)
        XCTAssertFalse(ImpactLog(bags: 1).isEmpty)
    }

    func testFakeCircuitStaysOnTheLoop() {
        let circuit = FakeData.walkCircuit
        XCTAssertGreaterThan(circuit.length, 300)
        let start = circuit.location(atDistance: 0, speed: 2.5)
        let wrapped = circuit.location(atDistance: circuit.length, speed: 2.5)
        XCTAssertLessThan(start.distance(from: wrapped), 1)
    }
}
