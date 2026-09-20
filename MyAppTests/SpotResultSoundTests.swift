import XCTest
@testable import MyApp

@MainActor
final class SpotResultSoundTests: XCTestCase {
    private func result(bags: Int = 3, waste: [WasteType] = [.plastic], model: String = "sim-1") -> ScannerResult {
        ScannerResult(wasteTypes: waste, severity: .medium, estimatedBags: bags, gear: [], hazard: .none,
                      peopleNeeded: 2, confidence: 0.9, modelVersion: model)
    }

    func testPlaysTheScanSoundOnceWhenTheEstimateAppears() {
        let sound = SilentSoundPlayer()
        let vm = SpotResultViewModel(result: result(), hasError: false, sound: sound)
        vm.onAppear()
        vm.onAppear()
        XCTAssertEqual(sound.played, [.scanResult], "only once, even if the screen re-appears")
        XCTAssertTrue(vm.hasAnnounced)
    }

    func testStaysSilentForManualFallbackErrorsAndEmptyResults() {
        let cases: [(ScannerResult, Bool)] = [
            (result(model: "manual"), false),
            (result(), true),
            (result(bags: 0), false),
            (result(waste: []), false),
        ]
        for (scan, hasError) in cases {
            let sound = SilentSoundPlayer()
            let vm = SpotResultViewModel(result: scan, hasError: hasError, sound: sound)
            vm.onAppear()
            XCTAssertTrue(sound.played.isEmpty)
        }
    }

    func testLeavingTheScreenStopsTheSound() {
        let sound = SilentSoundPlayer()
        let vm = SpotResultViewModel(result: result(), hasError: false, sound: sound)
        vm.onAppear()
        vm.onDisappear()
        XCTAssertEqual(sound.stopCount, 1)
    }

    func testTheMp3IsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: SoundEffect.scanResult.rawValue, withExtension: "mp3"))
    }
}
