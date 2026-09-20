import SwiftUI

/// Opens a Clean-Up by id (from a notification): loads it, then shows the regular detail screen.
struct CleanUpDetailRoute: View {
    let cleanUpId: UUID
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var repository
    @State private var cleanUp: CleanUp?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let cleanUp {
                CleanUpDetailView(cleanUp: cleanUp, selectedTab: $selectedTab)
            } else if didLoad {
                ContentUnavailableView("Clean-Up unavailable", systemImage: "leaf",
                                       description: Text("This Clean-Up is no longer available."))
            } else {
                ProgressView().tint(Eco.textPrimary)
            }
        }
        .task {
            cleanUp = try? await repository.cleanUp(id: cleanUpId)
            didLoad = true
        }
    }
}
