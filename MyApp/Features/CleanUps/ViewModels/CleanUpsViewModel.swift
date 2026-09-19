import Foundation
import Observation

/// Clean-Ups tab (Strava "Groups → Events"): my upcoming RSVPs, Clean-Ups near me, done ones.
@Observable @MainActor
final class CleanUpsViewModel {
    enum Segment: CaseIterable, Hashable {
        case upcoming, nearYou, done

        var title: String {
            switch self {
            case .upcoming: "Upcoming"
            case .nearYou: "Near you"
            case .done: "Done"
            }
        }
    }

    var segment: Segment = .upcoming
    private(set) var all: [CleanUp] = []
    /// A day picked on the calendar strip; filters Upcoming / Near you to that day.
    private(set) var selectedDay: Date?

    let userId: UUID
    private let repository: CleanUpRepository
    private let reference: Coordinate
    private let calendar: Calendar
    private let now: () -> Date

    init(userId: UUID, repository: CleanUpRepository, reference: Coordinate = Fixtures.homeCoordinate,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.userId = userId
        self.repository = repository
        self.reference = reference
        self.calendar = calendar
        self.now = now
    }

    func load() async {
        all = (try? await repository.all()) ?? []
    }

    /// Keeps the list live while the tab is visible.
    func subscribe() async {
        for await updated in repository.changes() { all = updated }
    }

    func toggleRSVP(_ cleanUp: CleanUp) async {
        let joining = !isAttending(cleanUp)
        _ = try? await repository.setRSVP(cleanUpId: cleanUp.id, userId: userId, joining: joining)
    }

    func isAttending(_ cleanUp: CleanUp) -> Bool { cleanUp.attendeeIds.contains(userId) }

    var items: [CleanUp] { items(for: segment) }

    var showsCalendar: Bool { segment != .done }

    /// The next 14 days, each with how many Clean-Ups of the current segment start that day.
    var calendarDays: [EcoCalendarDay] {
        let today = calendar.startOfDay(for: now())
        let base = baseItems(for: segment)
        return (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let count = base.filter { $0.startsAt.map { calendar.isDate($0, inSameDayAs: date) } ?? false }.count
            return EcoCalendarDay(date: date, eventCount: count)
        }
    }

    func selectDay(_ date: Date) {
        if let selectedDay, calendar.isDate(selectedDay, inSameDayAs: date) {
            self.selectedDay = nil
        } else {
            selectedDay = date
        }
    }

    func items(for segment: Segment) -> [CleanUp] {
        let base = baseItems(for: segment)
        guard segment != .done, let selectedDay else { return base }
        return base.filter { $0.startsAt.map { calendar.isDate($0, inSameDayAs: selectedDay) } ?? false }
    }

    private func baseItems(for segment: Segment) -> [CleanUp] {
        switch segment {
        case .upcoming:
            all.filter { $0.status != .done && isAttending($0) }
                .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
        case .nearYou:
            all.filter { $0.status != .done && !isAttending($0) }
                .sorted { reference.distance(to: $0.coordinate) < reference.distance(to: $1.coordinate) }
        case .done:
            all.filter { $0.status == .done }.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var emptyMessage: String {
        if selectedDay != nil, segment != .done { return "No Clean-Ups on this day. Pick another one." }
        return switch segment {
        case .upcoming: "You haven't joined a Clean-Up yet. Find one near you and RSVP."
        case .nearYou: "No open Clean-Ups nearby. Spot one!"
        case .done: "Finished Clean-Ups will show up here."
        }
    }

    func rsvpTitle(for cleanUp: CleanUp) -> String {
        isAttending(cleanUp) ? "Going" : (cleanUp.isFull ? "Full" : "RSVP")
    }

    func subtitle(for cleanUp: CleanUp) -> String {
        let meters = reference.distance(to: cleanUp.coordinate)
        let distance = meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
        return "\(cleanUp.status.label) · \(distance) · \(cleanUp.attendeeCount) going"
    }
}
