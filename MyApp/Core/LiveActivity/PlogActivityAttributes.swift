import ActivityKit
import Foundation

/// Shared by the app and the `EcoPlogWidgets` extension (both compile this file).
struct PlogActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Now minus elapsed": lets `Text(timerInterval:)` count on its own between updates.
        var timerStart: Date
        /// Set while paused so the timer freezes.
        var pausedAt: Date?
        var distanceMeters: Double
        var kcal: Int
        var bags: Int
        var heartRate: Int?

        var isPaused: Bool { pausedAt != nil }
    }

    var title: String
}

enum PlogFormat {
    static func distance(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters)) m" : String(format: "%.2f km", meters / 1000)
    }
}
