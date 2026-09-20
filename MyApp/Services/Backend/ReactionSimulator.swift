import Foundation

/// Fake "other people" reacting to what you post: after an activity is uploaded, an Eco-Boost, a comment and a
/// community like arrive a little later, each creating a notification. This makes the whole loop demoable
/// (finish activity → notification → tap → post screen) without a real backend.
actor ReactionSimulator {
    private let backend: FakeBackendService
    private let inbox: InboxService
    private let delays: [Duration]
    private let now: () -> Date

    private static let comments = [
        "Amazing work, that spot needed it! 🙌",
        "Love the before and after.",
        "Thank you for cleaning this up 🌱",
        "Count me in for the next one!",
    ]

    init(backend: FakeBackendService, inbox: InboxService,
         delays: [Duration] = [.seconds(15), .seconds(40), .seconds(90)], now: @escaping () -> Date = { .now }) {
        self.backend = backend
        self.inbox = inbox
        self.delays = delays
        self.now = now
    }

    /// Schedules the three reactions and returns when all of them have happened (tests await this).
    func react(to activity: Activity) async {
        guard activity.userId == User.demo.id, delays.count >= 3 else { return }
        let photo = activity.afterPhotoURL ?? activity.beforePhotoURL

        try? await Task.sleep(for: delays[0])
        await backend.addSimulatedBoost(on: activity.id, by: Fixtures.hostA)
        await inbox.add(AppNotification(
            kind: .activityLike, target: .activity(activity.id), commentID: nil,
            actorName: Fixtures.hostA.name, subject: activity.title, commentText: nil, photoURL: photo,
            createdAt: now(), isRead: false
        ))

        try? await Task.sleep(for: delays[1])
        let text = Self.comments[Int(activity.id.uuid.0) % Self.comments.count]
        let comment = await backend.addSimulatedComment(text, on: activity.id, by: Fixtures.hostB)
        await inbox.add(AppNotification(
            kind: .comment, target: .activity(activity.id), commentID: comment.id,
            actorName: Fixtures.hostB.name, subject: activity.title, commentText: text, photoURL: photo,
            createdAt: now(), isRead: false
        ))

        try? await Task.sleep(for: delays[2])
        await backend.addSimulatedBoost(on: activity.id, by: Fixtures.hostC)
        let target: NotificationTarget = activity.cleanUpId.map(NotificationTarget.cleanUp) ?? .activity(activity.id)
        await inbox.add(AppNotification(
            kind: .communityLike, target: target, commentID: nil,
            actorName: Fixtures.hostC.name, otherActorsCount: 3, subject: activity.title, commentText: nil, photoURL: photo,
            createdAt: now(), isRead: false
        ))
    }
}
