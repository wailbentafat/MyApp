import Foundation

/// Fake AI. Real pipeline (per the plan) is on-device Vision pre-check + a cloud
/// vision call through an Edge Function that holds the API key. This simulates the
/// same latency and failure/timeout shape with zero network calls and zero model —
/// it just samples from a fixed set of plausible-looking detections.
struct FakeScannerService: ScannerService {
    /// Injectable so previews/tests can force a specific outcome.
    var forcedOutcome: ScannerResult?
    /// Simulated timeout, matching the plan's "timeout + manual entry fallback" note.
    var simulateTimeout: Bool = false

    private static let library: [ScannerResult] = [
        ScannerResult(
            wasteTypes: [.plastic, .glass],
            severity: .medium,
            estimatedBags: 3,
            gear: Fixtures.gear(for: [.plastic, .glass]),
            hazard: .none,
            peopleNeeded: 2,
            confidence: 0.91,
            modelVersion: "ecoplog-vision-fake-v1"
        ),
        ScannerResult(
            wasteTypes: [.bulkItem, .metal],
            severity: .high,
            estimatedBags: 6,
            gear: Fixtures.gear(for: [.bulkItem, .metal]),
            hazard: .caution,
            peopleNeeded: 4,
            confidence: 0.84,
            modelVersion: "ecoplog-vision-fake-v1"
        ),
        ScannerResult(
            wasteTypes: [.plastic, .cigaretteButts],
            severity: .low,
            estimatedBags: 1,
            gear: Fixtures.gear(for: [.plastic, .cigaretteButts]),
            hazard: .none,
            peopleNeeded: 1,
            confidence: 0.95,
            modelVersion: "ecoplog-vision-fake-v1"
        ),
        ScannerResult(
            wasteTypes: [.hazardous, .plastic],
            severity: .high,
            estimatedBags: 4,
            gear: Fixtures.gear(for: [.hazardous, .plastic]),
            hazard: .hazardous,
            peopleNeeded: 2,
            confidence: 0.77,
            modelVersion: "ecoplog-vision-fake-v1"
        ),
        ScannerResult(
            wasteTypes: [.paper, .organic],
            severity: .low,
            estimatedBags: 2,
            gear: Fixtures.gear(for: [.paper, .organic]),
            hazard: .none,
            peopleNeeded: 1,
            confidence: 0.88,
            modelVersion: "ecoplog-vision-fake-v1"
        ),
    ]

    func analyse(imageData: Data) async throws -> ScannerResult {
        // Vision pre-check step, simulated.
        try await Task.sleep(for: .milliseconds(400))
        // "Cloud" classification step, simulated.
        try await Task.sleep(for: .milliseconds(.random(in: 700...1400)))

        if simulateTimeout {
            throw ScannerServiceError.timeout
        }
        if let forcedOutcome { return forcedOutcome }

        // Deterministic-ish pick so re-analysing the same photo tends to agree,
        // without needing any real image understanding.
        let seed = imageData.count
        return Self.library[seed % Self.library.count]
    }
}

enum ScannerServiceError: Error, LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout: "AI analysis timed out. You can enter waste details manually."
        }
    }
}
