import Foundation

/// Where the calorie number came from. The UI labels `.estimated` values.
enum EnergySource: String, Codable, Sendable {
    case estimated   // MET formula
    case healthKit   // active energy samples from Health / Apple Watch
}

/// One person's tracked workout, free or attached to a Clean-Up.
struct Activity: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var userId: String?
    var cleanUpId: UUID?
    var title: String = "Clean-Up"

    var startedAt: Date
    var endedAt: Date
    var movingSeconds: Double
    var route: [RoutePoint] = []
    var distanceMeters: Double = 0
    var elevationGainMeters: Double = 0

    var kcal: Double = 0
    var kcalSource: EnergySource = .estimated
    var averageHeartRate: Double?
    var steps: Int?

    var impact: ImpactLog = ImpactLog()

    /// Paths relative to `Documents/`, see `ActivityFiles`.
    var beforePhotoPath: String?
    var afterPhotoPath: String?
    var reelPath: String?

    var healthWorkoutId: UUID?
    var isUploaded: Bool = false

    var elapsedSeconds: Double { endedAt.timeIntervalSince(startedAt) }
}

/// How an activity is started.
enum ActivityContext: Hashable, Sendable {
    case free
    case cleanUp(CleanUp)

    var cleanUp: CleanUp? {
        if case .cleanUp(let cleanUp) = self { cleanUp } else { nil }
    }
}
