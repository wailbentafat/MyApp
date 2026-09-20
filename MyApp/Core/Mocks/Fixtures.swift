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

    /// Deterministic "random" offset (same seed, same place) so seeded pins never move between launches.
    private static func jitter(_ coordinate: Coordinate, meters: Double, seed: Int = 0) -> Coordinate {
        let degreesPerMeter = 1.0 / 111_000.0
        let a = Double((seed &* 7919 &+ 13) % 1000) / 1000
        let b = Double((seed &* 104_729 &+ 71) % 1000) / 1000
        let dLat = (a * 2 - 1) * meters * degreesPerMeter
        let dLon = (b * 2 - 1) * meters * degreesPerMeter
        return Coordinate(latitude: coordinate.latitude + dLat, longitude: coordinate.longitude + dLon)
    }

    static func gear(for wasteTypes: [WasteType]) -> [GearItem] {
        var seen = Set<String>()
        var items: [GearItem] = []
        for type in wasteTypes {
            for name in type.suggestedGear where seen.insert(name).inserted {
                items.append(GearItem(name: name, systemImage: type.systemImage, committedCount: name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 5))
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
        var counter = 0
        func cleanUp(
            _ title: String, photo: String, heading: Double, waste: [WasteType], severity: Severity, bags: Int,
            hazard: HazardLevel = .none, starts: Date?, capacity: Int, host: User, status: CleanUpStatus,
            attendees: [User], meters: Double, created: TimeInterval
        ) -> CleanUp {
            counter += 1
            return CleanUp(
                id: SeedIDs.cleanUp(counter), title: title, coordinate: jitter(coordinate, meters: meters, seed: counter),
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
        var counter = 0
        func post(_ user: User, _ title: String, before: String, after: String, km: Double, kcal: Double,
                  bags: Int, kudos: Int, liked: Bool = false, ago: TimeInterval) -> FeedPost {
            counter += 1
            return FeedPost(
                id: SeedIDs.post(counter), activityId: SeedIDs.feedActivity(counter), authorId: user.id,
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
        var counter = 0
        func activity(_ title: String, daysAgo: Double, km: Double, minutes: Double, bags: Int, kg: Double,
                      steps: Int, after: String?, before: String? = nil) -> Activity {
            let start = now.addingTimeInterval(-daysAgo * 86_400)
            counter += 1
            return Activity(
                id: SeedIDs.activity(counter), userId: user.id, cleanUpId: nil,
                startedAt: start, endedAt: start.addingTimeInterval(minutes * 60),
                route: route(distance: km * 1000, at: start),
                distance: km * 1000, duration: minutes * 60, elevation: 12 + km * 4, kcal: km * 62,
                avgHR: 118, steps: steps,
                impactLog: ImpactLog(bags: bags, kg: kg, itemCounts: ["plastic": bags * 6, "glass": bags]),
                afterPhotoURL: after.flatMap(DemoPhotos.url), reelURL: nil,
                title: title, kcalIsEstimated: false, healthWorkoutId: UUID(),
                beforePhotoURL: before.flatMap(DemoPhotos.url)
            )
        }
        return [
            activity("Morning Clean-Up", daysAgo: 1.2, km: 3.4, minutes: 42, bags: 3, kg: 6.5, steps: 4600, after: "after_park_bridge", before: "before_creek"),
            activity("Riverside sweep", daysAgo: 4.1, km: 2.1, minutes: 31, bags: 2, kg: 4, steps: 3100, after: "after_river", before: "before_river"),
            activity("Evening plog", daysAgo: 8.3, km: 5.2, minutes: 58, bags: 4, kg: 9, steps: 7200, after: "after_path", before: "before_street"),
            activity("Beach path clean-up", daysAgo: 11.0, km: 2.8, minutes: 40, bags: 5, kg: 11, steps: 3900, after: "after_beach", before: "before_beach"),
            activity("Trail stewards walk", daysAgo: 16.5, km: 4.3, minutes: 55, bags: 3, kg: 5, steps: 6000, after: "after_trail", before: "before_wetland"),
            activity("Lunch-break litter pick", daysAgo: 20.2, km: 1.6, minutes: 24, bags: 2, kg: 3, steps: 2300, after: nil),
            activity("Wetland creek litter", daysAgo: 27.0, km: 3.0, minutes: 47, bags: 4, kg: 8.5, steps: 4300, after: "after_trail", before: "before_wetland"),
            activity("First cleanup", daysAgo: 33.4, km: 1.9, minutes: 29, bags: 2, kg: 3.5, steps: 2700, after: "after_park_bridge", before: "before_creek"),
        ]
    }

    /// Comments on my activities (the ones the inbox mentions) and on a few community posts.
    static func seedComments() -> [Comment] {
        let now = Date()
        func comment(_ index: Int, on target: UUID, _ user: User, _ text: String, ago: TimeInterval) -> Comment {
            Comment(id: SeedIDs.comment(index), targetId: target, authorId: user.id, authorName: user.name,
                    text: text, createdAt: now.addingTimeInterval(-ago))
        }
        return [
            comment(1, on: SeedIDs.activity(1), hostB, "Great work! That park looks so much better already.", ago: 2_400),
            comment(2, on: SeedIDs.activity(1), hostA, "Love seeing the before and after 🙌", ago: 5_000),
            comment(3, on: SeedIDs.activity(2), hostF, "Count me in for the next one 🙌", ago: 30_000),
            comment(4, on: SeedIDs.activity(3), hostC, "5 km with 4 bags, that's a serious plog!", ago: 130_000),
            comment(5, on: SeedIDs.activity(5), hostD, "Love this trail, thanks for cleaning it up!", ago: 420_000),
            comment(6, on: SeedIDs.feedActivity(1), hostC, "Ocean Beach looks incredible now.", ago: 3_000),
            comment(7, on: SeedIDs.feedActivity(1), hostA, "Wish I could have joined, next time!", ago: 3_600),
            comment(8, on: SeedIDs.feedActivity(3), hostE, "That wetland needed this so much.", ago: 90_000),
        ]
    }

    /// Who gave an Eco-Boost to which activity (keyed by activity id string).
    static func seedBoosts() -> [String: [BoosterRef]] {
        func refs(_ users: [User]) -> [BoosterRef] { users.map { BoosterRef(userId: $0.id, name: $0.name) } }
        return [
            SeedIDs.activity(1).uuidString: refs([hostC, hostA, hostD]),
            SeedIDs.activity(2).uuidString: refs([hostD, hostB]),
            SeedIDs.activity(3).uuidString: refs([hostA]),
            SeedIDs.activity(4).uuidString: refs([hostF, hostC]),
            SeedIDs.feedActivity(1).uuidString: refs([hostC, hostA, User.demo]),
            SeedIDs.feedActivity(2).uuidString: refs([hostB, hostD]),
            SeedIDs.feedActivity(3).uuidString: refs([hostA, hostE]),
        ]
    }

    /// Inbox: likes on my activities, comments, and community reactions, spread over the last week.
    static func seedNotifications() -> [AppNotification] {
        let now = Date()
        func item(_ kind: NotificationKind, _ actor: User, others: Int = 0, _ subject: String,
                  target: NotificationTarget, comment: Int? = nil, text: String? = nil,
                  photo: String? = nil, ago: TimeInterval, read: Bool = false) -> AppNotification {
            AppNotification(kind: kind, target: target, commentID: comment.map(SeedIDs.comment),
                            actorName: actor.name, otherActorsCount: others, subject: subject,
                            commentText: text, photoURL: photo.flatMap(DemoPhotos.url),
                            createdAt: now.addingTimeInterval(-ago), isRead: read)
        }
        return [
            item(.activityLike, hostC, "Morning Clean-Up", target: .activity(SeedIDs.activity(1)), photo: "after_park_bridge", ago: 900),
            item(.comment, hostB, "Morning Clean-Up", target: .activity(SeedIDs.activity(1)), comment: 1,
                 text: "Great work! That park looks so much better already.", photo: "after_park_bridge", ago: 2_400),
            item(.communityLike, hostA, others: 4, "Beach path clean-up", target: .cleanUp(SeedIDs.cleanUp(1)), photo: "before_beach", ago: 5_400),
            item(.activityLike, hostD, "Riverside sweep", target: .activity(SeedIDs.activity(2)), photo: "after_river", ago: 14_000),
            item(.comment, hostF, "Riverside sweep", target: .activity(SeedIDs.activity(2)), comment: 3,
                 text: "Count me in for the next one 🙌", photo: "after_river", ago: 30_000),
            item(.communityLike, hostE, others: 11, "Street corner rescue", target: .cleanUp(SeedIDs.cleanUp(3)), photo: "before_street", ago: 60_000, read: true),
            item(.activityLike, hostA, "Evening plog", target: .activity(SeedIDs.activity(3)), photo: "after_path", ago: 100_000, read: true),
            item(.comment, hostC, "Evening plog", target: .activity(SeedIDs.activity(3)), comment: 4,
                 text: "5 km with 4 bags, that's a serious plog!", photo: "after_path", ago: 130_000, read: true),
            item(.communityLike, hostB, others: 7, "Wetland creek litter", target: .cleanUp(SeedIDs.cleanUp(4)), photo: "before_wetland", ago: 220_000, read: true),
            item(.activityLike, hostF, "Beach path clean-up", target: .activity(SeedIDs.activity(4)), photo: "after_beach", ago: 300_000, read: true),
            item(.comment, hostD, "Trail stewards walk", target: .activity(SeedIDs.activity(5)), comment: 5,
                 text: "Love this trail, thanks for cleaning it up!", photo: "after_trail", ago: 420_000, read: true),
            item(.activityLike, hostE, "First cleanup", target: .activity(SeedIDs.activity(8)), photo: "after_park_bridge", ago: 700_000, read: true),
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
