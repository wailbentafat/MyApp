import Foundation
import Observation

/// Clean-Up detail sheet: RSVP, gear checklist, and finishing an activity started from here.
@Observable @MainActor
final class CleanUpDetailViewModel {
    private(set) var cleanUp: CleanUp
    private(set) var isJoining = false
    private(set) var committedGear: Set<String> = []

    private let user: User?
    private let repository: CleanUpRepository
    private let completion: ActivityCompletionCoordinator

    init(cleanUp: CleanUp, user: User?, repository: CleanUpRepository, completion: ActivityCompletionCoordinator) {
        self.cleanUp = cleanUp
        self.user = user
        self.repository = repository
        self.completion = completion
    }

    /// The sheet is re-presented with a fresh value when the map's realtime stream updates it.
    func update(_ fresh: CleanUp) { cleanUp = fresh }

    // MARK: State

    var isAttending: Bool {
        guard let user else { return false }
        return cleanUp.attendeeIds.contains(user.id)
    }

    var isHost: Bool { cleanUp.hostId == user?.id }
    var isDone: Bool { cleanUp.status == .done }
    var canStartActivity: Bool { (isAttending || isHost) && !isDone }

    var rsvpTitle: String {
        isAttending ? "Leave Clean-Up" : (cleanUp.isFull ? "Full" : "RSVP — I'm in")
    }

    var isRSVPDisabled: Bool { isJoining || (!isAttending && cleanUp.isFull) }

    var attendeeLabel: String {
        if let capacity = cleanUp.capacity { return "\(cleanUp.attendeeCount)/\(capacity)" }
        return "\(cleanUp.attendeeCount)"
    }

    // MARK: Gear checklist

    func isCommitted(_ item: GearItem) -> Bool { committedGear.contains(item.name) }

    func bringingText(for item: GearItem) -> String {
        "\(item.committedCount + (isCommitted(item) ? 1 : 0)) bringing"
    }

    func toggleGear(_ item: GearItem) {
        if committedGear.contains(item.name) {
            committedGear.remove(item.name)
        } else {
            committedGear.insert(item.name)
        }
    }

    // MARK: Actions

    func toggleRSVP() async {
        guard let user, !isJoining else { return }
        isJoining = true
        defer { isJoining = false }
        if let updated = try? await repository.setRSVP(cleanUpId: cleanUp.id, userId: user.id, joining: !isAttending) {
            cleanUp = updated
        }
    }

    /// Uploads the finished activity, closes this Clean-Up and posts it to the feed.
    func finish(_ activity: Activity) async {
        guard let user else { return }
        await completion.complete(activity, cleanUp: cleanUp, author: user)
    }
}
