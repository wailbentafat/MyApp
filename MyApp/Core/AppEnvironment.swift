import Foundation

/// Composition root: the one place that decides fake vs live implementations.
/// While `useFakeData` is true the app runs entirely on simulated GPS, health data and in-memory repositories.
@MainActor
enum AppEnvironment {
    static var useFakeData = true

    static let activityRepository: any ActivityRepository = MockActivityRepository(seed: FakeData.activities)
    static let cleanUpRepository: any CleanUpRepository = MockCleanUpRepository(seed: FakeData.cleanUps)

    static func makeActivityViewModel(context: ActivityContext) -> ActivityViewModel {
        ActivityViewModel(
            context: context,
            location: useFakeData ? FakeLocationProvider() : LiveLocationProvider(),
            health: FakeHealthProvider(),   // Live HealthKit provider arrives in Phase 3
            activities: activityRepository,
            cleanUps: cleanUpRepository
        )
    }
}
