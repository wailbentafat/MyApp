import SwiftUI

/// Strava-style activity summary: title, route map, stat grid, impact.
struct ActivitySummaryView: View {
    let viewModel: ActivityViewModel
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.l) {
                VStack(alignment: .leading, spacing: Eco.Space.xs) {
                    Text(viewModel.savedActivity?.title ?? viewModel.title)
                        .font(.ecoDisplaySmall)
                        .foregroundStyle(Eco.textPrimary)
                    Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                }

                RouteMapView(coordinates: viewModel.coordinates)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Eco.Space.m) {
                    EcoStatTile(value: viewModel.distanceValueText + " km", label: "Distance", systemImage: "figure.walk")
                    EcoStatTile(value: viewModel.timeText, label: "Moving time", systemImage: "timer")
                    EcoStatTile(value: viewModel.averagePaceText + " /km", label: "Avg pace", systemImage: "speedometer")
                    EcoStatTile(value: viewModel.elevationText + " m", label: "Elevation gain", systemImage: "mountain.2.fill")
                    EcoStatTile(value: viewModel.kcalText, label: viewModel.energyLabel, systemImage: "flame.fill")
                    EcoStatTile(value: viewModel.stepsText, label: "Steps", systemImage: "shoeprints.fill")
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Impact")
                    HStack(spacing: Eco.Space.xl) {
                        EcoMetric(label: "Bags", value: String(viewModel.impact.bags))
                        EcoMetric(label: "Weight", value: String(format: "%.1f", viewModel.impact.kg), unit: "kg")
                        EcoMetric(label: "Items", value: String(viewModel.impact.totalItems))
                    }
                    let categories = WasteCategory.allCases.filter { (viewModel.impact.items[$0] ?? 0) > 0 }
                    if !categories.isEmpty {
                        HStack {
                            ForEach(categories, id: \.self) { category in
                                EcoChip(title: "\(category.label) \(viewModel.impact.items[category] ?? 0)",
                                        systemImage: category.systemImage, isSelected: true)
                            }
                        }
                    }
                }
                .ecoCard()

                Button("Done", action: onDone)
                    .buttonStyle(.eco)
            }
            .padding(Eco.Space.l)
        }
    }
}
