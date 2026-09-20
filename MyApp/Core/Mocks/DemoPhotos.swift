import Foundation

/// Real demo photos bundled in `Resources/Photos` (credits in `docs/PHOTO_CREDITS.md`).
/// `before_*` = polluted spots, `after_*` = cleaned/clean places, `crew_*` = volunteers at work.
enum DemoPhotos {
    static func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    /// Fake-data pairing: the clean "after" that goes with a polluted "before" photo.
    static func pairedAfter(for beforeURL: URL?) -> URL? {
        guard let name = beforeURL?.deletingPathExtension().lastPathComponent else { return nil }
        let pairs = [
            "before_river": "after_river", "before_creek": "after_park_bridge", "before_wetland": "after_trail",
            "before_beach": "after_beach", "before_bridge": "after_river", "before_street": "after_path",
        ]
        return pairs[name].flatMap(url)
    }

    static var beforeNames: [String] { ["before_river", "before_creek", "before_wetland", "before_beach", "before_bridge", "before_street"] }
    static var afterNames: [String] { ["after_beach", "after_park_bridge", "after_trail", "after_path", "after_river"] }
    static var crewNames: [String] { ["crew_beach", "crew_hikers", "crew_ranger", "crew_kid", "crew_city", "crew_climbers"] }
}
