import AVFoundation
import SwiftUI

/// Short UI sounds bundled in `Resources/Sounds`.
enum SoundEffect: String, CaseIterable {
    /// Played when the scan result (waste, bags, gear) appears.
    case scanResult = "scan_result"
}

/// Thin wrapper over AVFoundation audio. No business rules: *when* to play lives in view models.
@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ sound: SoundEffect)
    func stop()
}

@MainActor
final class LiveSoundPlayer: SoundPlaying {
    private var player: AVAudioPlayer?

    func play(_ sound: SoundEffect) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else { return }
        do {
            // `.ambient` mixes with other audio and follows the silent switch.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player?.stop()
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

/// Records what would have played (tests, previews).
@MainActor
final class SilentSoundPlayer: SoundPlaying {
    private(set) var played: [SoundEffect] = []
    private(set) var stopCount = 0

    func play(_ sound: SoundEffect) { played.append(sound) }
    func stop() { stopCount += 1 }
}

private struct SoundPlayerKey: EnvironmentKey {
    @MainActor static let defaultValue: any SoundPlaying = LiveSoundPlayer()
}

extension EnvironmentValues {
    @MainActor
    var soundPlayer: any SoundPlaying {
        get { self[SoundPlayerKey.self] }
        set { self[SoundPlayerKey.self] = newValue }
    }
}
