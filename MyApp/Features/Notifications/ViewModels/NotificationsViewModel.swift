import Foundation
import Observation

/// Notifications screen: filter (All / Likes / Comments / Community), day sections, read state.
@Observable @MainActor
final class NotificationsViewModel {
    enum Filter: CaseIterable, Hashable {
        case all, likes, comments, community

        var title: String {
            switch self {
            case .all: "All"
            case .likes: "Likes"
            case .comments: "Comments"
            case .community: "Community"
            }
        }

        func includes(_ kind: NotificationKind) -> Bool {
            switch self {
            case .all: true
            case .likes: kind == .activityLike
            case .comments: kind == .comment
            case .community: kind == .communityLike
            }
        }
    }

    struct Section: Identifiable {
        let title: String
        let items: [AppNotification]
        var id: String { title }
    }

    /// Where a notification leads when tapped.
    enum NotificationDestination: Hashable {
        case post(activityId: UUID, highlightCommentID: UUID?)
        case cleanUp(id: UUID)
    }

    var filter: Filter = .all
    private(set) var all: [AppNotification] = []
    private(set) var isLoading = true

    private let inbox: InboxService
    private let calendar: Calendar
    private let now: () -> Date

    init(inbox: InboxService, calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.inbox = inbox
        self.calendar = calendar
        self.now = now
    }

    func load() async {
        all = await inbox.notifications()
        isLoading = false
    }

    // MARK: Derived

    var unreadCount: Int { all.filter { !$0.isRead }.count }
    var hasUnread: Bool { unreadCount > 0 }
    var filtered: [AppNotification] { all.filter { filter.includes($0.kind) } }
    var isEmpty: Bool { filtered.isEmpty }

    var emptyMessage: String {
        switch filter {
        case .all: "You're all caught up."
        case .likes: "No likes on your activities yet."
        case .comments: "No comments yet."
        case .community: "No community reactions yet."
        }
    }

    /// Items grouped as Today / Yesterday / This week / Earlier, newest first.
    var sections: [Section] {
        let today = calendar.startOfDay(for: now())
        var buckets: [String: [AppNotification]] = [:]
        for item in filtered {
            let day = calendar.startOfDay(for: item.createdAt)
            let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            let key = days <= 0 ? "Today" : (days == 1 ? "Yesterday" : (days < 7 ? "This week" : "Earlier"))
            buckets[key, default: []].append(item)
        }
        return ["Today", "Yesterday", "This week", "Earlier"].compactMap { key in
            buckets[key].map { Section(title: key, items: $0) }
        }
    }

    // MARK: Text

    /// Bold part of the row: "Priya Nair" or "Priya Nair and 4 others".
    func actorText(for item: AppNotification) -> String {
        item.otherActorsCount > 0
            ? "\(item.actorName) and \(item.otherActorsCount) other\(item.otherActorsCount == 1 ? "" : "s")"
            : item.actorName
    }

    func actionText(for item: AppNotification) -> String {
        switch item.kind {
        case .activityLike: " gave an Eco-Boost to your activity “\(item.subject)”."
        case .comment: " commented on your activity “\(item.subject)”."
        case .communityLike: " liked your Clean-Up “\(item.subject)”."
        }
    }

    func iconName(for kind: NotificationKind) -> String {
        switch kind {
        case .activityLike: "hand.thumbsup"
        case .comment: "bubble.left.fill"
        case .communityLike: "heart"
        }
    }

    func timeText(for item: AppNotification) -> String {
        item.createdAt.formatted(.relative(presentation: .named))
    }

    // MARK: Actions

    /// Marks the notification read and says where it leads.
    @discardableResult
    func open(_ item: AppNotification) async -> NotificationDestination {
        if !item.isRead {
            await inbox.markRead(id: item.id)
            await load()
        }
        return destination(for: item)
    }

    func destination(for item: AppNotification) -> NotificationDestination {
        switch item.target {
        case .activity(let id): .post(activityId: id, highlightCommentID: item.commentID)
        case .cleanUp(let id): .cleanUp(id: id)
        }
    }

    /// Live updates (new reactions arriving while the screen is open).
    func subscribe() async {
        for await items in inbox.changes() {
            all = items
            isLoading = false
        }
    }

    func markAllRead() async {
        await inbox.markAllRead()
        await load()
    }
}
