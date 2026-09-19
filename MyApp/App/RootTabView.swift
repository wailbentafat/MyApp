import SwiftUI

enum AppTab: Hashable {
    case map, spot, feed, profile
}

/// The 4-tab shell from the plan's screen map. P2-owned (App/ + routing).
struct RootTabView: View {
    @State private var selectedTab: AppTab = .map

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CleanUpMapView(selectedTab: $selectedTab)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(AppTab.map)

            NavigationStack {
                SpotFlowView(onPublished: { selectedTab = .map })
            }
            .tabItem { Label("Spot", systemImage: "camera.viewfinder") }
            .tag(AppTab.spot)

            NavigationStack {
                FeedView()
            }
            .tabItem { Label("Feed", systemImage: "figure.run.circle.fill") }
            .tag(AppTab.feed)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Me", systemImage: "person.fill") }
            .tag(AppTab.profile)
        }
        .tint(Eco.primary)
    }
}

#Preview {
    RootTabView()
        .ecoTheme()
}
