import SwiftUI

enum AppTab: Hashable {
    case home, map, record, cleanUps, profile
}

/// The app shell: a native `TabView`, so on iOS 26 the tab bar is the system Liquid Glass bar and all five
/// tabs sit in it equally: Home · Maps · Record · Clean-Ups · You.
/// "Record" is not a screen: selecting it opens the Record sheet and the previous tab stays selected.
struct RootTabView: View {
    private enum Pending { case spot, activity(CleanUp?) }
    private struct ActivityRequest: Identifiable {
        let id = UUID()
        let cleanUp: CleanUp?
    }

    @State private var selectedTab: AppTab = Self.debugInitialTab
    @State private var showRecordSheet = false
    @State private var pending: Pending?
    @State private var showSpot = false
    @State private var activityRequest: ActivityRequest?

    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.feedService) private var feedService
    @Environment(\.appSession) private var appSession

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", image: "ic-house", value: AppTab.home) {
                HomeView(selectedTab: $selectedTab, onSpot: { showSpot = true }, onRecord: { showRecordSheet = true })
            }
            Tab("Maps", image: "ic-map", value: AppTab.map) {
                NavigationStack { CleanUpMapView(selectedTab: $selectedTab) }
            }
            Tab("Record", image: "ic-circle-plus", value: AppTab.record) {
                Color.clear
            }
            Tab("Clean-Ups", image: "ic-calendar-days", value: AppTab.cleanUps) {
                CleanUpsView(selectedTab: $selectedTab)
            }
            Tab("You", image: "ic-user", value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
        }
        .tint(Eco.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .record {
                selectedTab = oldValue
                showRecordSheet = true
            }
        }
        .onAppear(perform: applyDebugShow)
        .sheet(isPresented: $showRecordSheet, onDismiss: presentPending) {
            RecordSheetView { choice in
                switch choice {
                case .spot: pending = .spot
                case .freeActivity: pending = .activity(nil)
                case .cleanUp(let cleanUp): pending = .activity(cleanUp)
                }
                showRecordSheet = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .ecoTheme()
        }
        .fullScreenCover(isPresented: $showSpot) {
            NavigationStack {
                SpotFlowView(onPublished: {
                    showSpot = false
                    selectedTab = .map
                })
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { showSpot = false }
                    }
                }
            }
            .ecoTheme()
        }
        .fullScreenCover(item: $activityRequest) { request in
            ActivityFlowLauncher(cleanUp: request.cleanUp) { activity in
                finish(activity, cleanUp: request.cleanUp)
            }
            .ecoTheme()
        }
    }

    private static var debugInitialTab: AppTab {
        switch DebugLaunch.value(after: "-ecoTab") {
        case "map": .map
        case "cleanUps": .cleanUps
        case "profile": .profile
        default: .home
        }
    }

    private func applyDebugShow() {
        switch DebugLaunch.value(after: "-ecoShow") {
        case "record": showRecordSheet = true
        case "spot": showSpot = true
        case "activity": activityRequest = ActivityRequest(cleanUp: nil)
        case "activityCleanUp": activityRequest = ActivityRequest(cleanUp: Fixtures.seedCleanUps()[0])
        default: break
        }
    }

    private func presentPending() {
        defer { pending = nil }
        switch pending {
        case .spot: showSpot = true
        case .activity(let cleanUp): activityRequest = ActivityRequest(cleanUp: cleanUp)
        case nil: break
        }
    }

    private func finish(_ activity: Activity, cleanUp: CleanUp?) {
        guard let user = appSession.currentUser else { return }
        let coordinator = ActivityCompletionCoordinator(
            activities: activityRepository, cleanUps: cleanUpRepository, feed: feedService
        )
        Task {
            await coordinator.complete(activity, cleanUp: cleanUp, author: user)
            selectedTab = .home
        }
    }
}

#Preview {
    RootTabView()
        .ecoTheme()
}
