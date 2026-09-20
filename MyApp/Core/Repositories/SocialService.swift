import Foundation
import SwiftUI

struct BoostSummary: Equatable, Sendable {
    var count: Int
    var isBoostedByMe: Bool
    /// A few booster names for "Maya, Diego and 25 others gave Eco-Boost".
    var names: [String]
}

/// Comments and Eco-Boosts (likes) on activities / posts. Keyed by the activity id, so a community feed post and
/// the activity behind it always agree.
protocol SocialService: Sendable {
    func comments(for activityId: UUID) async -> [Comment]
    func addComment(text: String, on activityId: UUID, by user: User) async throws -> Comment
    func boostSummary(for activityId: UUID, userId: UUID) async -> BoostSummary
    @discardableResult
    func toggleBoost(on activityId: UUID, by user: User) async -> BoostSummary
}

/// Fake services that can go back to their seed data ("Reset demo data").
protocol DemoDataResetting: Sendable {
    func resetToSeed() async
}

private struct SocialServiceKey: EnvironmentKey {
    static let defaultValue: any SocialService = FakeBackendService()
}

extension EnvironmentValues {
    var socialService: any SocialService {
        get { self[SocialServiceKey.self] }
        set { self[SocialServiceKey.self] = newValue }
    }
}

private struct DemoDataResetterKey: EnvironmentKey {
    static let defaultValue: any DemoDataResetting = DemoDataResetter(targets: [])
}

extension EnvironmentValues {
    var demoDataResetter: any DemoDataResetting {
        get { self[DemoDataResetterKey.self] }
        set { self[DemoDataResetterKey.self] = newValue }
    }
}
