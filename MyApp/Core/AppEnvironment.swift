import Foundation

/// Picks fake vs live sensor implementations for the Activity flow.
/// While `useFakeData` is true the app runs on a simulated GPS walk and fake heart rate/steps.
/// Repositories are NOT created here: they come from SwiftUI's `Environment` (Person 2's backend).
@MainActor
enum AppEnvironment {
    static var useFakeData = true

    /// The real camera when the device has one, otherwise the demo-photo fake (simulator).
    static func makeCamera() -> CameraProviding {
        let live = LiveCameraProvider()
        return live.isAvailable ? live : FakeCameraProvider()
    }

    static func makeActivityViewModel(
        context: ActivityContext,
        userId: UUID,
        activities: any ActivityRepository
    ) -> ActivityViewModel {
        ActivityViewModel(
            context: context,
            userId: userId,
            location: useFakeData ? FakeLocationProvider() : LiveLocationProvider(),
            health: FakeHealthProvider(),   // Live HealthKit provider arrives with the HealthKit phase
            activities: activities
        )
    }
}
