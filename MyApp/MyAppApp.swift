import SwiftUI

@main
struct MyAppApp: App {
    @State private var appSession = AppSession()
    @Environment(\.scenePhase) private var scenePhase

    /// One shared, persisted stack (JSON files in Application Support): the backend implements the Clean-Up,
    /// Activity, Feed and Social services, so every feature sees the same data (a Clean-Up created in Spot shows up
    /// in the Map, a finished Activity shows up in Profile and the Feed, ...) and it survives relaunches.
    private let services = AppEnvironment.makeServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appSession, appSession)
                .environment(\.cleanUpRepository, services.backend)
                .environment(\.activityRepository, services.backend)
                .environment(\.feedService, services.backend)
                .environment(\.socialService, services.backend)
                .environment(\.inboxService, services.inbox)
                .environment(\.demoDataResetter, services.resetter)
                .environment(\.scannerService, FakeScannerService())
                .environment(\.notificationService, FakeNotificationService())
                .environment(\.shareService, FakeShareService())
                .ecoTheme()
                .task {
                    await services.installHooks()
                    if DebugLaunch.autoSignIn { await appSession.signInWithApple() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { Task { await services.flush() } }
                }
        }
    }
}
