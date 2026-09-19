import Foundation

/// Seed/demo data shared by every fake service, so the app is populated the moment
/// it launches (no backend, no sign-in required to see something real-looking).
enum Fixtures {
    /// Roughly San Francisco's Mission district — dense enough that a few hundred
    /// meters of jitter still reads as "nearby" on the map.
    static let homeCoordinate = Coordinate(latitude: 37.7599, longitude: -122.4148)

    static let hostA = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Maya Chen",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 12, bagsCollected: 34, kgCollected: 96, distanceKm: 61)
    )

    static let hostB = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Diego Ramos",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 7, bagsCollected: 19, kgCollected: 52, distanceKm: 33)
    )

    static let hostC = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Priya Nair",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 20, bagsCollected: 58, kgCollected: 140, distanceKm: 90)
    )

    static var demoUsers: [User] { [hostA, hostB, hostC] }

    private static func jitter(_ coordinate: Coordinate, meters: Double) -> Coordinate {
        let degreesPerMeter = 1.0 / 111_000.0
        let dLat = Double.random(in: -meters...meters) * degreesPerMeter
        let dLon = Double.random(in: -meters...meters) * degreesPerMeter
        return Coordinate(latitude: coordinate.latitude + dLat, longitude: coordinate.longitude + dLon)
    }

    static func gear(for wasteTypes: [WasteType]) -> [GearItem] {
        var seen = Set<String>()
        var items: [GearItem] = []
        for type in wasteTypes {
            for name in type.suggestedGear where seen.insert(name).inserted {
                items.append(GearItem(name: name, systemImage: type.systemImage, committedCount: Int.random(in: 0...4)))
            }
        }
        return items
    }

    /// A handful of Clean-Ups across every status, so the map/feed never look empty.
    static func seedCleanUps(near coordinate: Coordinate = homeCoordinate) -> [CleanUp] {
        let now = Date()
        return [
            CleanUp(
                id: UUID(),
                title: "Dolores Park east lawn",
                coordinate: jitter(coordinate, meters: 300),
                beforePhotoURL: nil,
                beforeHeading: 45,
                wasteTypes: [.plastic, .glass],
                severity: .medium,
                estimatedBags: 4,
                gear: gear(for: [.plastic, .glass]),
                hazard: .none,
                startsAt: now.addingTimeInterval(3600 * 3),
                capacity: 8,
                hostId: hostA.id,
                hostName: hostA.name,
                status: .open,
                attendeeIds: [hostA.id],
                doneActivityIds: [],
                createdAt: now.addingTimeInterval(-3600)
            ),
            CleanUp(
                id: UUID(),
                title: "Under the 16th St overpass",
                coordinate: jitter(coordinate, meters: 600),
                beforePhotoURL: nil,
                beforeHeading: 120,
                wasteTypes: [.bulkItem, .hazardous],
                severity: .high,
                estimatedBags: 9,
                gear: gear(for: [.bulkItem, .hazardous]),
                hazard: .caution,
                startsAt: now.addingTimeInterval(3600 * 26),
                capacity: 6,
                hostId: hostB.id,
                hostName: hostB.name,
                status: .scheduled,
                attendeeIds: [hostB.id, hostA.id],
                doneActivityIds: [],
                createdAt: now.addingTimeInterval(-7200)
            ),
            CleanUp(
                id: UUID(),
                title: "Baker Beach tide line",
                coordinate: jitter(coordinate, meters: 900),
                beforePhotoURL: nil,
                beforeHeading: 200,
                wasteTypes: [.plastic, .cigaretteButts],
                severity: .low,
                estimatedBags: 2,
                gear: gear(for: [.plastic, .cigaretteButts]),
                hazard: .none,
                startsAt: now.addingTimeInterval(-600),
                capacity: 10,
                hostId: hostC.id,
                hostName: hostC.name,
                status: .live,
                attendeeIds: [hostC.id, hostB.id, hostA.id],
                doneActivityIds: [],
                createdAt: now.addingTimeInterval(-10_800)
            ),
            CleanUp(
                id: UUID(),
                title: "Mission Creek bike path",
                coordinate: jitter(coordinate, meters: 450),
                beforePhotoURL: nil,
                beforeHeading: 300,
                wasteTypes: [.paper, .organic],
                severity: .low,
                estimatedBags: 3,
                gear: gear(for: [.paper, .organic]),
                hazard: .none,
                startsAt: now.addingTimeInterval(-86_400),
                capacity: 5,
                hostId: hostA.id,
                hostName: hostA.name,
                status: .done,
                attendeeIds: [hostA.id, hostC.id],
                doneActivityIds: [UUID()],
                createdAt: now.addingTimeInterval(-172_800)
            ),
        ]
    }

    static func seedFeedPosts() -> [FeedPost] {
        let now = Date()
        return [
            FeedPost(
                id: UUID(), activityId: UUID(), authorId: hostC.id,
                authorName: hostC.name, authorAvatarSystemImage: hostC.avatarSystemImage,
                cleanUpTitle: "Mission Creek bike path",
                beforePhotoURL: nil, afterPhotoURL: nil,
                distanceKm: 2.4, kcal: 180, bags: 3,
                kudosCount: 14, kudosGivenByMe: false,
                createdAt: now.addingTimeInterval(-86_400)
            ),
            FeedPost(
                id: UUID(), activityId: UUID(), authorId: hostB.id,
                authorName: hostB.name, authorAvatarSystemImage: hostB.avatarSystemImage,
                cleanUpTitle: "Ocean Beach dune trail",
                beforePhotoURL: nil, afterPhotoURL: nil,
                distanceKm: 4.1, kcal: 310, bags: 5,
                kudosCount: 27, kudosGivenByMe: true,
                createdAt: now.addingTimeInterval(-190_000)
            ),
        ]
    }

    static func seedBadges() -> [Badge] {
        [
            Badge(id: "first-spot", title: "First Spot", systemImage: "camera.viewfinder", achievedAt: Date().addingTimeInterval(-2_000_000)),
            Badge(id: "five-cleanups", title: "5 Clean-Ups", systemImage: "checkmark.seal.fill", achievedAt: Date().addingTimeInterval(-500_000)),
            Badge(id: "ten-bags", title: "10 Bags Collected", systemImage: "trash.circle.fill", achievedAt: Date().addingTimeInterval(-100_000)),
            Badge(id: "streak-3", title: "3-Week Streak", systemImage: "flame.fill", achievedAt: nil),
            Badge(id: "hundred-km", title: "100 km Cleaned", systemImage: "figure.walk.circle.fill", achievedAt: nil),
        ]
    }
}
