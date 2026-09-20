import Foundation
import Observation

/// Spot result screen: decides when the "scan result" sound plays (once, when the AI estimate is shown).
@Observable @MainActor
final class SpotResultViewModel {
    private(set) var hasAnnounced = false

    private let result: ScannerResult
    private let hasError: Bool
    private let sound: SoundPlaying

    init(result: ScannerResult, hasError: Bool, sound: SoundPlaying) {
        self.result = result
        self.hasError = hasError
        self.sound = sound
    }

    /// Only for a real AI estimate: not for the manual-entry fallback shown when analysis failed, and not when there is
    /// nothing to announce.
    var shouldAnnounce: Bool {
        !hasError && result.modelVersion != "manual" && result.estimatedBags > 0 && !result.wasteTypes.isEmpty
    }

    func onAppear() {
        guard shouldAnnounce, !hasAnnounced else { return }
        hasAnnounced = true
        sound.play(.scanResult)
    }

    func onDisappear() {
        sound.stop()
    }
}
