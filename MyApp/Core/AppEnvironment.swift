import Foundation

/// Picks fake vs live sensor implementations for the Activity flow.
/// While `useFakeData` is true the app runs on a simulated GPS walk and fake heart rate/steps.
/// Repositories are NOT created here: they come from SwiftUI's `Environment` (Person 2's backend).
/// The long-lived fake services of the app: one persisted backend, one persisted inbox, and the simulator that makes
/// other people react to what you post.
struct AppServices {
    let backend: FakeBackendService
    let inbox: FakeInboxService
    let simulator: ReactionSimulator

    var resetter: DemoDataResetter { DemoDataResetter(targets: [backend, inbox]) }

    func installHooks() async {
        await backend.setUploadHook { [simulator] activity in await simulator.react(to: activity) }
    }

    /// Writes any pending changes to disk (called when the app leaves the foreground).
    func flush() async {
        await backend.flush()
    }
}

/// Puts every persisted fake service back to its seed data.
struct DemoDataResetter: DemoDataResetting {
    let targets: [any DemoDataResetting]

    func resetToSeed() async {
        for target in targets { await target.resetToSeed() }
    }
}

@MainActor
enum AppEnvironment {
    static var useFakeData = true

    /// Builds the persisted fake backend + inbox (JSON files in Application Support).
    static func makeServices() -> AppServices {
        let store = JSONDocumentStore()
        if DebugLaunch.resetData { store.removeAll() }
        let backend = FakeBackendService(store: store, persistDelay: .milliseconds(300))
        let inbox = FakeInboxService(store: store)
        return AppServices(backend: backend, inbox: inbox, simulator: ReactionSimulator(backend: backend, inbox: inbox))
    }

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
