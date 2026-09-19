import SwiftUI

// MARK: - Contracts (shared with Person 2)

protocol ActivityRepository: Sendable {
    func save(_ activity: Activity) async throws
    func history() async throws -> [Activity]
    /// Pushes a finished activity to the backend. Local impl marks it pending.
    func upload(_ activity: Activity) async throws
}

protocol CleanUpRepository: Sendable {
    func cleanUp(id: UUID) async throws -> CleanUp?
    /// Marks the Clean-Up done once an activity attached to it is finished.
    func complete(cleanUpId: UUID, activityId: UUID) async throws
}

// MARK: - Mocks (used until the real implementations land)

actor MockActivityRepository: ActivityRepository {
    private var storage: [Activity]

    init(seed: [Activity] = []) { storage = seed }

    func save(_ activity: Activity) async throws {
        if let index = storage.firstIndex(where: { $0.id == activity.id }) {
            storage[index] = activity
        } else {
            storage.append(activity)
        }
    }

    func history() async throws -> [Activity] {
        storage.sorted { $0.startedAt > $1.startedAt }
    }

    func upload(_ activity: Activity) async throws {
        var uploaded = activity
        uploaded.isUploaded = true
        try await save(uploaded)
    }
}

actor MockCleanUpRepository: CleanUpRepository {
    private var storage: [UUID: CleanUp]
    private(set) var completed: [UUID: UUID] = [:]

    init(seed: [CleanUp] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func cleanUp(id: UUID) async throws -> CleanUp? { storage[id] }

    func complete(cleanUpId: UUID, activityId: UUID) async throws {
        completed[cleanUpId] = activityId
        storage[cleanUpId]?.status = .done
    }
}

// MARK: - Environment injection

private struct ActivityRepositoryKey: EnvironmentKey {
    static let defaultValue: any ActivityRepository = MockActivityRepository()
}

private struct CleanUpRepositoryKey: EnvironmentKey {
    static let defaultValue: any CleanUpRepository = MockCleanUpRepository()
}

extension EnvironmentValues {
    var activityRepository: any ActivityRepository {
        get { self[ActivityRepositoryKey.self] }
        set { self[ActivityRepositoryKey.self] = newValue }
    }

    var cleanUpRepository: any CleanUpRepository {
        get { self[CleanUpRepositoryKey.self] }
        set { self[CleanUpRepositoryKey.self] = newValue }
    }
}
