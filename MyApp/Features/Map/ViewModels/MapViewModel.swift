import Foundation
import Observation

/// Maps tab: which Clean-Ups are shown (status filter), the selected pin, and where the camera points.
@Observable @MainActor
final class MapViewModel {
    /// Where the map camera should be. The view animates to it whenever it changes.
    struct Target: Equatable {
        var center: Coordinate
        var span: Double
    }

    /// `nil` = "All".
    static let filters: [CleanUpStatus?] = [nil] + CleanUpStatus.allCases.map { Optional($0) }

    private(set) var cleanUps: [CleanUp] = []
    private(set) var target: Target
    var statusFilter: CleanUpStatus?
    var selectedCleanUp: CleanUp?

    private let repository: CleanUpRepository
    private let location: LocationFixing

    init(repository: CleanUpRepository, location: LocationFixing, center: Coordinate = Fixtures.homeCoordinate) {
        self.repository = repository
        self.location = location
        self.target = Target(center: center, span: 0.03)
    }

    // MARK: Loading

    func load() async {
        cleanUps = (try? await repository.all()) ?? []
    }

    /// Keeps pins live (RSVPs, new Spots) and refreshes the open detail sheet.
    func subscribe() async {
        for await updated in repository.changes() {
            cleanUps = updated
            if let selected = selectedCleanUp, let fresh = updated.first(where: { $0.id == selected.id }) {
                selectedCleanUp = fresh
            }
        }
    }

    func centerOnMe() async {
        location.requestWhenInUseAuthorization()
        guard let fix = await location.requestFix() else { return }
        target = Target(center: fix.coordinate, span: 0.02)
    }

    // MARK: Filtering

    var visibleCleanUps: [CleanUp] {
        guard let statusFilter else { return cleanUps }
        return cleanUps.filter { $0.status == statusFilter }
    }

    func count(for status: CleanUpStatus?) -> Int {
        guard let status else { return cleanUps.count }
        return cleanUps.filter { $0.status == status }.count
    }

    func chipTitle(for status: CleanUpStatus?) -> String {
        let name = status?.label ?? "All"
        let count = count(for: status)
        return count > 0 ? "\(name) \(count)" : name
    }

    func select(_ status: CleanUpStatus?) {
        statusFilter = status
    }

    func isSelected(_ status: CleanUpStatus?) -> Bool { statusFilter == status }

    // MARK: Display

    func bagsText(for cleanUp: CleanUp) -> String { String(cleanUp.estimatedBags) }
}
