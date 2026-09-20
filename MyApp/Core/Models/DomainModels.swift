import CoreLocation
import Foundation

// MARK: - Coordinate

/// Codable, Hashable stand-in for `CLLocationCoordinate2D` (which is neither).
struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    /// Great-circle distance in meters (haversine).
    func distance(to other: Coordinate) -> Double {
        let r = 6_371_000.0
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}

// MARK: - User

struct User: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var avatarSystemImage: String
    var totals: Totals

    struct Totals: Codable, Hashable, Sendable {
        var cleanUpsJoined: Int = 0
        var bagsCollected: Int = 0
        var kgCollected: Double = 0
        var distanceKm: Double = 0
    }

    static let demo = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
        name: "Wail Bentafat",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 8, bagsCollected: 26, kgCollected: 71, distanceKm: 27.4)
    )
}

// MARK: - Waste / gear / hazard

enum WasteType: String, Codable, CaseIterable, Identifiable, Sendable {
    case plastic, glass, metal, paper, organic, bulkItem, cigaretteButts, hazardous, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plastic: "Plastic"
        case .glass: "Glass"
        case .metal: "Metal"
        case .paper: "Paper"
        case .organic: "Organic"
        case .bulkItem: "Bulk item"
        case .cigaretteButts: "Cigarette butts"
        case .hazardous: "Hazardous"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .plastic: "bag.fill"
        case .glass: "wineglass.fill"
        case .metal: "trash.fill"
        case .paper: "newspaper.fill"
        case .organic: "leaf.fill"
        case .bulkItem: "sofa.fill"
        case .cigaretteButts: "smoke.fill"
        case .hazardous: "exclamationmark.triangle.fill"
        case .other: "questionmark.circle.fill"
        }
    }

    /// Gear this waste type usually calls for. Combined + de-duplicated across a scan's waste types.
    var suggestedGear: [String] {
        switch self {
        case .plastic: ["50L trash bag", "Grabber tool"]
        case .glass: ["Heavy-duty gloves", "Puncture-resistant bag"]
        case .metal: ["Heavy-duty gloves", "Grabber tool"]
        case .paper: ["30L trash bag"]
        case .organic: ["Gloves", "Compost bag"]
        case .bulkItem: ["Extra pair of hands", "Trolley or cart"]
        case .cigaretteButts: ["Small bucket", "Tweezers or grabber"]
        case .hazardous: ["Heavy-duty gloves", "Face mask", "Puncture-resistant bag"]
        case .other: ["Gloves", "Trash bag"]
        }
    }
}

enum Severity: String, Codable, CaseIterable, Sendable {
    case low, medium, high

    var label: String {
        switch self {
        case .low: "Light"
        case .medium: "Moderate"
        case .high: "Heavy"
        }
    }
}

enum HazardLevel: String, Codable, CaseIterable, Sendable {
    case none, caution, hazardous

    var message: String? {
        switch self {
        case .none: nil
        case .caution: "Some items may be sharp. Wear gloves and handle with care."
        case .hazardous: "Hazardous material detected. Don't touch — report to the city instead."
        }
    }
}

struct GearItem: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var systemImage: String
    /// How many attendees have committed to bringing this item (fake community count).
    var committedCount: Int = 0
}

// MARK: - Scanner (AI) result

struct ScannerResult: Codable, Hashable, Sendable {
    var wasteTypes: [WasteType]
    var severity: Severity
    var estimatedBags: Int
    var gear: [GearItem]
    var hazard: HazardLevel
    var peopleNeeded: Int
    /// Simulated model confidence, purely cosmetic — this pipeline is a local fake, not a real model.
    var confidence: Double
    var modelVersion: String
}

// MARK: - Clean-Up

enum CleanUpStatus: String, Codable, CaseIterable, Sendable {
    case open, scheduled, live, done

    var label: String {
        switch self {
        case .open: "Open"
        case .scheduled: "Scheduled"
        case .live: "Live"
        case .done: "Done"
        }
    }

    var tint: String {
        switch self {
        case .open: "primary"
        case .scheduled: "info"
        case .live: "warning"
        case .done: "hint"
        }
    }
}

struct CleanUp: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var coordinate: Coordinate
    var beforePhotoURL: URL?
    var beforeHeading: Double
    var wasteTypes: [WasteType]
    var severity: Severity
    var estimatedBags: Int
    var gear: [GearItem]
    var hazard: HazardLevel
    var startsAt: Date?
    var capacity: Int?
    var hostId: UUID
    var hostName: String
    var status: CleanUpStatus
    var attendeeIds: [UUID]
    var doneActivityIds: [UUID]
    var createdAt: Date

    var attendeeCount: Int { attendeeIds.count }
    var isFull: Bool {
        guard let capacity else { return false }
        return attendeeCount >= capacity
    }
}

/// What the Spot flow hands to the repository to create a `CleanUp`.
struct CleanUpDraft: Sendable {
    var title: String
    var coordinate: Coordinate
    var beforePhotoData: Data?
    var beforeHeading: Double
    var wasteTypes: [WasteType]
    var severity: Severity
    var estimatedBags: Int
    var gear: [GearItem]
    var hazard: HazardLevel
    var startsAt: Date?
    var capacity: Int?
}

// MARK: - RSVP

struct RSVP: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var cleanUpId: UUID
    var userId: UUID
    var createdAt: Date
}

// MARK: - Activity (produced by P1's flow; P2 stores/uploads it)

struct RoutePoint: Codable, Hashable, Sendable {
    var coordinate: Coordinate
    var timestamp: Date
}

struct ImpactLog: Codable, Hashable, Sendable {
    var bags: Int = 0
    var kg: Double = 0
    var itemCounts: [String: Int] = [:]
}

struct Activity: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var cleanUpId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var route: [RoutePoint]
    var distance: Double
    var duration: TimeInterval
    var elevation: Double
    var kcal: Double
    var avgHR: Double?
    var steps: Int
    var impactLog: ImpactLog
    var afterPhotoURL: URL?
    var reelURL: URL?
    /// Added by P1 (defaults keep P2's initialisers valid).
    var title: String = "Clean-Up"
    /// `true` while `kcal` comes from the MET formula, `false` once HealthKit energy replaced it.
    var kcalIsEstimated: Bool = true
    var healthWorkoutId: UUID?
    /// The Clean-Up's Spot photo (the story's "Before"). Nil for free activities.
    var beforePhotoURL: URL?
}

// MARK: - Community feed

struct FeedPost: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var activityId: UUID
    var authorId: UUID
    var authorName: String
    var authorAvatarSystemImage: String
    var cleanUpTitle: String
    var beforePhotoURL: URL?
    var afterPhotoURL: URL?
    var distanceKm: Double
    var kcal: Double
    var bags: Int
    var kudosCount: Int
    var kudosGivenByMe: Bool
    var createdAt: Date
}

// MARK: - Badges

struct Badge: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var systemImage: String
    var achievedAt: Date?

    var isEarned: Bool { achievedAt != nil }
}
