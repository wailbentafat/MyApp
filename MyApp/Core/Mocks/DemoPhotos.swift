import Foundation

/// Real demo photos bundled in `Resources/Photos` (credits in `docs/PHOTO_CREDITS.md`).
/// `before_*` = polluted spots, `after_*` = cleaned/clean places, `crew_*` = volunteers at work.
enum DemoPhotos {
    static func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    static var beforeNames: [String] { ["before_river", "before_creek", "before_wetland", "before_beach", "before_bridge", "before_street"] }
    static var afterNames: [String] { ["after_beach", "after_park_bridge", "after_trail", "after_path", "after_river"] }
    static var crewNames: [String] { ["crew_beach", "crew_hikers", "crew_ranger", "crew_kid", "crew_city", "crew_climbers"] }
}
