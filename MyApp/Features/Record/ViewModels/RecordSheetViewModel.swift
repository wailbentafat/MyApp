import Foundation
import Observation

/// The sheet opened by the center Record button: Spot pollution, or start an activity (free or for a Clean-Up I joined).
@Observable @MainActor
final class RecordSheetViewModel {
    private(set) var myCleanUps: [CleanUp] = []

    private let userId: UUID
    private let repository: CleanUpRepository

    init(userId: UUID, repository: CleanUpRepository) {
        self.userId = userId
        self.repository = repository
    }

    func load() async {
        let all = (try? await repository.all()) ?? []
        myCleanUps = all
            .filter { $0.attendeeIds.contains(userId) && $0.status != .done }
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
    }

    func timeText(for cleanUp: CleanUp) -> String {
        guard let date = cleanUp.startsAt else { return cleanUp.status.label }
        return cleanUp.status == .live ? "Live now" : date.formatted(date: .abbreviated, time: .shortened)
    }
}
