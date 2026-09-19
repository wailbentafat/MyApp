import CoreLocation
import Foundation

enum CleanUpStatus: String, Codable, Sendable {
    case open, scheduled, live, done
}

/// A polluted spot turned into a community event. Minimal shape used by the Activity flow;
/// Person 2 owns and extends it (attendees, capacity, startsAt, host…).
struct CleanUp: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var latitude: Double
    var longitude: Double
    /// The Spot photo. It is the "Before" of the Reel and the ghost overlay of the After camera.
    var beforePhotoURL: URL?
    /// Compass heading (degrees, 0 = north) the Before photo was taken with.
    var beforeHeading: Double?
    var status: CleanUpStatus = .open
    var wasteTypes: [WasteCategory] = []
    var gear: [String] = []
    var estimatedBags: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
