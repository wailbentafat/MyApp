import SwiftUI

/// The in-app notification inbox (likes, comments, community reactions). Not to be confused with
/// `NotificationService`, which schedules local/push notifications.
protocol InboxService: Sendable {
    func notifications() async -> [AppNotification]
    func unreadCount() async -> Int
    func markRead(id: UUID) async
    func markAllRead() async
    func add(_ notification: AppNotification) async
    /// Emits the full list whenever it changes (new reactions arriving, read state). Default: never emits.
    func changes() -> AsyncStream<[AppNotification]>
}

extension InboxService {
    func changes() -> AsyncStream<[AppNotification]> { AsyncStream { $0.finish() } }
}

struct InboxState: Codable {
    var items: [AppNotification]
}

/// Fake inbox, persisted to `inbox.json` so read state and newly arrived notifications survive relaunches.
actor FakeInboxService: InboxService, DemoDataResetting {
    static let storeName = "inbox"

    private var items: [AppNotification]
    private let store: DocumentStore
    private let latency: ClosedRange<Int>
    private var streams: [UUID: AsyncStream<[AppNotification]>.Continuation] = [:]

    init(store: DocumentStore = InMemoryDocumentStore(), seed: [AppNotification]? = nil, latency: ClosedRange<Int> = 250...250) {
        self.store = store
        self.latency = latency
        if let saved = store.load(InboxState.self, name: Self.storeName) {
            items = saved.items
        } else {
            items = seed ?? Fixtures.seedNotifications()
            try? store.save(InboxState(items: items), name: Self.storeName)
        }
    }

    /// Convenience for tests: a fresh in-memory inbox with exactly these items.
    init(items: [AppNotification]) {
        self.init(store: InMemoryDocumentStore(), seed: items, latency: 0...0)
    }

    private func commit() {
        try? store.save(InboxState(items: items), name: Self.storeName)
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        for continuation in streams.values { continuation.yield(sorted) }
    }

    func notifications() async -> [AppNotification] {
        if latency.upperBound > 0 { try? await Task.sleep(for: .milliseconds(latency.upperBound)) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func unreadCount() async -> Int { items.filter { !$0.isRead }.count }

    func markRead(id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isRead else { return }
        items[index].isRead = true
        commit()
    }

    func markAllRead() async {
        for index in items.indices { items[index].isRead = true }
        commit()
    }

    func add(_ notification: AppNotification) async {
        items.append(notification)
        commit()
    }

    func resetToSeed() async {
        items = Fixtures.seedNotifications()
        commit()
    }

    nonisolated func changes() -> AsyncStream<[AppNotification]> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<[AppNotification]>.Continuation) {
        streams[id] = continuation
        continuation.yield(items.sorted { $0.createdAt > $1.createdAt })
    }

    private func unregister(id: UUID) { streams[id] = nil }
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
