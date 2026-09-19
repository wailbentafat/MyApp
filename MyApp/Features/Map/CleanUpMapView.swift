import MapKit
import SwiftUI

struct CleanUpMapView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @State private var locationProvider = LocationFixProvider()

    @State private var cleanUps: [CleanUp] = []
    @State private var statusFilter: CleanUpStatus?
    @State private var selectedCleanUp: CleanUp?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: Fixtures.homeCoordinate.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )

    private var filtered: [CleanUp] {
        guard let statusFilter else { return cleanUps }
        return cleanUps.filter { $0.status == statusFilter }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                ForEach(filtered) { cleanUp in
                    Annotation(cleanUp.title, coordinate: cleanUp.coordinate.clLocationCoordinate) {
                        CleanUpPin(status: cleanUp.status)
                            .onTapGesture { selectedCleanUp = cleanUp }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea(edges: .bottom)

            filterBar
        }
        .navigationTitle("Clean-Ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await centerOnMe() }
                } label: {
                    Image(systemName: "location.fill")
                }
            }
        }
        .sheet(item: $selectedCleanUp) { cleanUp in
            NavigationStack {
                CleanUpDetailView(cleanUp: cleanUp, selectedTab: $selectedTab)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await load() }
        .task { await subscribeToChanges() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Eco.Space.s) {
                FilterChip(title: "All", isSelected: statusFilter == nil) { statusFilter = nil }
                ForEach(CleanUpStatus.allCases, id: \.self) { status in
                    FilterChip(title: status.label, isSelected: statusFilter == status) { statusFilter = status }
                }
            }
            .padding(Eco.Space.m)
        }
        .background(.ultraThinMaterial)
    }

    private func load() async {
        cleanUps = (try? await cleanUpRepository.all()) ?? []
    }

    private func subscribeToChanges() async {
        for await updated in cleanUpRepository.changes() {
            cleanUps = updated
            if let selectedCleanUp, let fresh = updated.first(where: { $0.id == selectedCleanUp.id }) {
                self.selectedCleanUp = fresh
            }
        }
    }

    private func centerOnMe() async {
        locationProvider.requestWhenInUseAuthorization()
        guard let fix = await locationProvider.requestFix() else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: fix.coordinate.clLocationCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )
        }
    }
}

private struct CleanUpPin: View {
    let status: CleanUpStatus

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, tint)
            .shadow(radius: 2)
    }

    private var tint: Color {
        switch status {
        case .open: Eco.primary
        case .scheduled: Eco.info
        case .live: Eco.warning
        case .done: Eco.textHint
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EcoChip(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { CleanUpMapView(selectedTab: .constant(.map)) }
        .ecoTheme()
}
