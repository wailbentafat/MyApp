import Foundation
import UIKit

/// Contracts P2 owns. Everyone (P1 included) codes against these while the real
/// backend/AI don't exist yet — see `Core/Mocks` and `Services/Backend` for the
/// in-memory fakes that satisfy them today.

// MARK: - Clean-Ups

protocol CleanUpRepository: Sendable {
    func all() async throws -> [CleanUp]
    func nearby(coordinate: Coordinate, radiusMeters: Double) async throws -> [CleanUp]
    func cleanUp(id: UUID) async throws -> CleanUp?
    @discardableResult
    func create(_ draft: CleanUpDraft, host: User) async throws -> CleanUp
    @discardableResult
    func setRSVP(cleanUpId: UUID, userId: UUID, joining: Bool) async throws -> CleanUp
    @discardableResult
    func updateStatus(cleanUpId: UUID, status: CleanUpStatus) async throws -> CleanUp
    @discardableResult
    func complete(cleanUpId: UUID, activityId: UUID) async throws -> CleanUp
    /// Fake "realtime": a stream that re-publishes the whole list whenever it changes,
    /// standing in for a Supabase realtime channel.
    func changes() -> AsyncStream<[CleanUp]>
}

// MARK: - Activities

protocol ActivityRepository: Sendable {
    func save(_ activity: Activity) async throws
    func history(userId: UUID) async throws -> [Activity]
    @discardableResult
    func upload(_ activity: Activity) async throws -> Activity
    /// Live list of one user's activities (newest first); emits on every change. Default: never emits.
    func changes(userId: UUID) -> AsyncStream<[Activity]>
}

extension ActivityRepository {
    func changes(userId: UUID) -> AsyncStream<[Activity]> { AsyncStream { $0.finish() } }
}

// MARK: - Community feed

protocol FeedService: Sendable {
    func recentPosts() async throws -> [FeedPost]
    @discardableResult
    func toggleKudos(postId: UUID, userId: UUID) async throws -> FeedPost
    /// Appends a finished Activity as a new feed post.
    func publish(activity: Activity, cleanUp: CleanUp, author: User) async
    /// Live feed; emits on every change (kudos, new posts). Default: never emits.
    func changes() -> AsyncStream<[FeedPost]>
}

extension FeedService {
    func changes() -> AsyncStream<[FeedPost]> { AsyncStream { $0.finish() } }
}

// MARK: - AI scanner

protocol ScannerService: Sendable {
    /// Analyses a Spot photo. This is a local simulation of the "on-device Vision
    /// pre-check + cloud vision Edge Function" pipeline described in the plan —
    /// no network call and no model actually run.
    func analyse(imageData: Data) async throws -> ScannerResult
}

// MARK: - Notifications

protocol NotificationService: Sendable {
    func requestAuthorization() async -> Bool
    /// Stands in for "Edge Function on Clean-Up insert selects users within ~3km
    /// and sends APNs" — fires a local notification instead, as the plan's own
    /// documented demo fallback.
    func notifyNearby(of cleanUp: CleanUp) async
    func scheduleReminder(for cleanUp: CleanUp) async
}

// MARK: - Share

enum ShareOutcome: Sendable {
    case postedToInstagram
    case openedShareSheet
    case cancelled
}

@MainActor
protocol ShareService {
    /// Tries Instagram Stories via the documented pasteboard hand-off; falls back
    /// to `UIActivityViewController` when Instagram isn't installed / reachable.
    func shareToInstagramStory(image: UIImage?, videoURL: URL?, caption: String) async -> ShareOutcome
}

// MARK: - Auth

protocol AuthService: Sendable {
    func signInWithApple() async throws -> User
    func signOut() async
}
