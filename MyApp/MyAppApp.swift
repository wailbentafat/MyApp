import SwiftUI

@main
struct MyAppApp: App {
    /// Everything below is P2's stack, wired to fakes: real Supabase and real AI
    /// don't exist in this build, on purpose — see `Services/Backend` and
    /// `Services/Backend/FakeScannerService.swift`.
    @State private var appSession = AppSession()
    /// One shared instance: it implements all three protocols, and every feature
    /// must see the same in-memory data (a Clean-Up created in Spot has to show
    /// up in the Map, its finished Activity has to show up in the Feed, etc).
    private let backend = FakeBackendService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appSession, appSession)
                .environment(\.cleanUpRepository, backend)
                .environment(\.activityRepository, backend)
                .environment(\.feedService, backend)
                .environment(\.scannerService, FakeScannerService())
                .environment(\.notificationService, FakeNotificationService())
                .environment(\.shareService, FakeShareService())
                .ecoTheme()
        }
    }
}
