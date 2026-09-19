import CoreLocation
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

    static var demoUsers: [User] { [hostA, hostB, hostC, hostD, hostE, hostF] }

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

    static let hostD = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Amira Belkacem",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 9, bagsCollected: 27, kgCollected: 70, distanceKm: 48)
    )

    static let hostE = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Lucas Meyer",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 5, bagsCollected: 12, kgCollected: 31, distanceKm: 22)
    )

    static let hostF = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "Sofia Rossi",
        avatarSystemImage: "person.crop.circle.fill",
        totals: .init(cleanUpsJoined: 15, bagsCollected: 44, kgCollected: 118, distanceKm: 77)
    )

    /// A date `days` from now at the given hour (fractional), so the calendar always has upcoming events.
    private static func day(_ days: Int, hour: Double, from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let base = calendar.date(byAdding: .day, value: days, to: start) ?? start
        return base.addingTimeInterval(hour * 3600)
    }

    /// Clean-Ups across every status with real photos, spread over the next two weeks (the calendar) plus
    /// a few finished ones. The demo user has joined several of them, so "Upcoming" is never empty.
    static func seedCleanUps(near coordinate: Coordinate = homeCoordinate) -> [CleanUp] {
        let now = Date()
        let me = User.demo
        func cleanUp(
            _ title: String, photo: String, heading: Double, waste: [WasteType], severity: Severity, bags: Int,
            hazard: HazardLevel = .none, starts: Date?, capacity: Int, host: User, status: CleanUpStatus,
            attendees: [User], meters: Double, created: TimeInterval
        ) -> CleanUp {
            CleanUp(
                id: UUID(), title: title, coordinate: jitter(coordinate, meters: meters),
                beforePhotoURL: DemoPhotos.url(photo), beforeHeading: heading,
                wasteTypes: waste, severity: severity, estimatedBags: bags,
                gear: gear(for: waste), hazard: hazard,
                startsAt: starts, capacity: capacity, hostId: host.id, hostName: host.name, status: status,
                attendeeIds: attendees.map(\.id), doneActivityIds: status == .done ? [UUID()] : [],
                createdAt: now.addingTimeInterval(created)
            )
        }
        return [
            cleanUp("Beach path clean-up", photo: "before_beach", heading: 200, waste: [.plastic, .glass],
                    severity: .medium, bags: 4, starts: now.addingTimeInterval(-600), capacity: 10,
                    host: hostC, status: .live, attendees: [hostC, hostB, me], meters: 500, created: -10_800),
            cleanUp("Riverside bottle sweep", photo: "before_river", heading: 45, waste: [.plastic],
                    severity: .medium, bags: 5, starts: day(1, hour: 8.5), capacity: 10,
                    host: hostA, status: .scheduled, attendees: [hostA, hostD, me], meters: 300, created: -7_200),
            cleanUp("Street corner rescue", photo: "before_street", heading: 90, waste: [.plastic, .paper, .cigaretteButts],
                    severity: .low, bags: 3, starts: day(2, hour: 18), capacity: 8,
                    host: hostE, status: .open, attendees: [hostE], meters: 250, created: -5_400),
            cleanUp("Wetland creek litter", photo: "before_wetland", heading: 120, waste: [.plastic, .organic],
                    severity: .high, bags: 7, hazard: .caution, starts: day(3, hour: 10), capacity: 12,
                    host: hostD, status: .scheduled, attendees: [hostD, hostB, me], meters: 700, created: -20_000),
            cleanUp("Bridge shoreline debris", photo: "before_bridge", heading: 300, waste: [.metal, .bulkItem],
                    severity: .high, bags: 9, hazard: .caution, starts: day(6, hour: 9), capacity: 15,
                    host: hostB, status: .scheduled, attendees: [hostB, hostF], meters: 900, created: -30_000),
            cleanUp("Roadside dump by the creek", photo: "before_creek", heading: 160, waste: [.bulkItem, .organic],
                    severity: .medium, bags: 4, starts: day(9, hour: 8), capacity: 10,
                    host: hostF, status: .scheduled, attendees: [hostF, me], meters: 800, created: -40_000),
            cleanUp("Ocean Beach dune trail", photo: "before_beach", heading: 250, waste: [.plastic, .cigaretteButts],
                    severity: .medium, bags: 5, starts: day(-3, hour: 9), capacity: 10,
                    host: hostB, status: .done, attendees: [hostB, hostC, me], meters: 1000, created: -300_000),
            cleanUp("Dolores lawn sweep", photo: "before_creek", heading: 30, waste: [.paper, .organic],
                    severity: .low, bags: 3, starts: day(-8, hour: 10), capacity: 6,
                    host: hostA, status: .done, attendees: [hostA, hostC], meters: 350, created: -700_000),
        ]
    }

    static func seedFeedPosts() -> [FeedPost] {
        let now = Date()
        func post(_ user: User, _ title: String, before: String, after: String, km: Double, kcal: Double,
                  bags: Int, kudos: Int, liked: Bool = false, ago: TimeInterval) -> FeedPost {
            FeedPost(
                id: UUID(), activityId: UUID(), authorId: user.id,
                authorName: user.name, authorAvatarSystemImage: user.avatarSystemImage,
                cleanUpTitle: title,
                beforePhotoURL: DemoPhotos.url(before), afterPhotoURL: DemoPhotos.url(after),
                distanceKm: km, kcal: kcal, bags: bags, kudosCount: kudos, kudosGivenByMe: liked,
                createdAt: now.addingTimeInterval(-ago)
            )
        }
        return [
            post(hostB, "Ocean Beach dune trail", before: "before_beach", after: "after_beach", km: 4.1, kcal: 310, bags: 5, kudos: 27, liked: true, ago: 5_400),
            post(hostC, "Dolores lawn sweep", before: "before_creek", after: "after_park_bridge", km: 2.4, kcal: 180, bags: 3, kudos: 14, ago: 86_400),
            post(hostD, "Wetland restoration walk", before: "before_wetland", after: "after_trail", km: 3.2, kcal: 240, bags: 6, kudos: 41, ago: 130_000),
            post(hostA, "Riverbank morning run", before: "before_river", after: "after_river", km: 5.6, kcal: 420, bags: 4, kudos: 33, ago: 200_000),
            post(hostF, "Street corner rescue", before: "before_street", after: "after_path", km: 1.8, kcal: 130, bags: 3, kudos: 9, ago: 290_000),
            post(hostE, "Bridge shoreline debris", before: "before_bridge", after: "after_river", km: 2.9, kcal: 210, bags: 8, kudos: 22, ago: 400_000),
        ]
    }

    /// The demo user's own history (drives Profile history, the weekly streak and the You stats).
    static func seedActivities(for user: User = .demo) -> [Activity] {
        let now = Date()
        func route(distance: Double, at start: Date) -> [RoutePoint] {
            let circuit = FakeData.walkCircuit
            return stride(from: 0.0, through: max(distance, 300), by: 25).enumerated().map { index, meters in
                let fix = circuit.location(atDistance: meters, speed: 1.6)
                return RoutePoint(coordinate: Coordinate(fix.coordinate), timestamp: start.addingTimeInterval(Double(index) * 15))
            }
        }
        func activity(_ title: String, daysAgo: Double, km: Double, minutes: Double, bags: Int, kg: Double,
                      steps: Int, after: String?) -> Activity {
            let start = now.addingTimeInterval(-daysAgo * 86_400)
            return Activity(
                id: UUID(), userId: user.id, cleanUpId: nil,
                startedAt: start, endedAt: start.addingTimeInterval(minutes * 60),
                route: route(distance: km * 1000, at: start),
                distance: km * 1000, duration: minutes * 60, elevation: 12 + km * 4, kcal: km * 62,
                avgHR: 118, steps: steps,
                impactLog: ImpactLog(bags: bags, kg: kg, itemCounts: ["plastic": bags * 6, "glass": bags]),
                afterPhotoURL: after.flatMap(DemoPhotos.url), reelURL: nil,
                title: title, kcalIsEstimated: false, healthWorkoutId: UUID()
            )
        }
        return [
            activity("Morning Clean-Up", daysAgo: 1.2, km: 3.4, minutes: 42, bags: 3, kg: 6.5, steps: 4600, after: "after_park_bridge"),
            activity("Riverside sweep", daysAgo: 4.1, km: 2.1, minutes: 31, bags: 2, kg: 4, steps: 3100, after: "after_river"),
            activity("Evening plog", daysAgo: 8.3, km: 5.2, minutes: 58, bags: 4, kg: 9, steps: 7200, after: "after_path"),
            activity("Beach path clean-up", daysAgo: 11.0, km: 2.8, minutes: 40, bags: 5, kg: 11, steps: 3900, after: "after_beach"),
            activity("Trail stewards walk", daysAgo: 16.5, km: 4.3, minutes: 55, bags: 3, kg: 5, steps: 6000, after: "after_trail"),
            activity("Lunch-break litter pick", daysAgo: 20.2, km: 1.6, minutes: 24, bags: 2, kg: 3, steps: 2300, after: nil),
            activity("Wetland creek litter", daysAgo: 27.0, km: 3.0, minutes: 47, bags: 4, kg: 8.5, steps: 4300, after: "after_trail"),
            activity("First cleanup", daysAgo: 33.4, km: 1.9, minutes: 29, bags: 2, kg: 3.5, steps: 2700, after: "after_park_bridge"),
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
