import SwiftUI

/// The in-app notification inbox (likes, comments, community reactions). Not to be confused with
/// `NotificationService`, which schedules local/push notifications.
protocol InboxService: Sendable {
    func notifications() async -> [AppNotification]
    func unreadCount() async -> Int
    func markRead(id: UUID) async
    func markAllRead() async
}

actor FakeInboxService: InboxService {
    private var items: [AppNotification]

    init(items: [AppNotification] = Fixtures.seedNotifications()) {
        self.items = items
    }

    func notifications() async -> [AppNotification] {
        try? await Task.sleep(for: .milliseconds(250))
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func unreadCount() async -> Int { items.filter { !$0.isRead }.count }

    func markRead(id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isRead = true
    }

    func markAllRead() async {
        for index in items.indices { items[index].isRead = true }
    }
}

private struct InboxServiceKey: EnvironmentKey {
    static let defaultValue: any InboxService = FakeInboxService()
}

extension EnvironmentValues {
    var inboxService: any InboxService {
        get { self[InboxServiceKey.self] }
        set { self[InboxServiceKey.self] = newValue }
    }
}
