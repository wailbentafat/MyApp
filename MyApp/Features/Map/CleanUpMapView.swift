import MapKit
import SwiftUI

/// Maps tab. Owns only the view model; all state and logic live in `MapViewModel`.
struct CleanUpMapView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @State private var viewModel: MapViewModel?

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                MapContent(viewModel: viewModel, selectedTab: $selectedTab)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard viewModel == nil else { return }
            let model = MapViewModel(repository: cleanUpRepository, location: LocationFixProvider())
            viewModel = model
            await model.load()
            await model.subscribe()
        }
    }
}

private struct MapContent: View {
    @Bindable var viewModel: MapViewModel
    @Binding var selectedTab: AppTab

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(viewModel.visibleCleanUps) { cleanUp in
                    Annotation(cleanUp.title, coordinate: cleanUp.coordinate.clLocationCoordinate, anchor: .bottom) {
                        CleanUpMarker(cleanUp: cleanUp, bagsText: viewModel.bagsText(for: cleanUp))
                            .onTapGesture { viewModel.selectedCleanUp = cleanUp }
                    }
                }
            }
            .mapControls { MapCompass() }
            .ignoresSafeArea()

            VStack(spacing: Eco.Space.s) {
                EcoTopBar(title: "Maps") {
                    EmptyView()
                } trailing: {
                    EmptyView()
                }
                .background(.ultraThinMaterial)

                filterBar

                Spacer()

                HStack {
                    Spacer()
                    EcoCircleButton(systemImage: "location.fill", label: "Center on my location", size: 52) {
                        Task { await viewModel.centerOnMe() }
                    }
                }
                .padding(.horizontal, Eco.Space.l)
                .padding(.bottom, Eco.Space.s)
            }
        }
        .onChange(of: viewModel.target, initial: true) { _, target in
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .region(MKCoordinateRegion(
                    center: target.center.clLocationCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: target.span, longitudeDelta: target.span)
                ))
            }
        }
        .sheet(item: $viewModel.selectedCleanUp) { cleanUp in
            NavigationStack {
                CleanUpDetailView(cleanUp: cleanUp, selectedTab: $selectedTab)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .ecoTheme()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Eco.Space.s) {
                ForEach(MapViewModel.filters, id: \.self) { status in
                    Button {
                        viewModel.select(status)
                    } label: {
                        Text(viewModel.chipTitle(for: status))
                            .font(.ecoLabelMedium)
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(viewModel.isSelected(status) ? Eco.onButton : Eco.textPrimary)
                            .padding(.horizontal, Eco.Space.m)
                            .padding(.vertical, Eco.Space.s)
                            .background(viewModel.isSelected(status) ? Eco.buttonFill : Eco.surface, in: Capsule())
                            .overlay(Capsule().stroke(Eco.border, lineWidth: viewModel.isSelected(status) ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.isSelected(status) ? .isSelected : [])
                }
            }
            .padding(.horizontal, Eco.Space.l)
        }
    }
}

#Preview {
    NavigationStack { CleanUpMapView(selectedTab: .constant(.map)) }
        .ecoTheme()
}
