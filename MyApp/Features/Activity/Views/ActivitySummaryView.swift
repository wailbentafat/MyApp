import SwiftUI

/// Strava-style activity post shown after saving: title, stats row, impact banner, route + photos, impact.
struct ActivitySummaryView: View {
    let viewModel: ActivityViewModel
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.l) {
                VStack(alignment: .leading, spacing: Eco.Space.xs) {
                    Text(viewModel.summaryTitle)
                        .font(.ecoDisplaySmall)
                        .foregroundStyle(Eco.textPrimary)
                    Text(viewModel.dateText)
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                }

                EcoStatRow(stats: [
                    EcoStat(label: "Distance", value: viewModel.distanceValueText + " km"),
                    EcoStat(label: "Pace", value: viewModel.averagePaceText + " /km"),
                    EcoStat(label: "Time", value: viewModel.timeText),
                ])

                EcoBanner(systemImage: "leaf.circle.fill", title: viewModel.impactBannerTitle,
                          subtitle: viewModel.impact.bags > 0 ? "\(viewModel.impact.bags) bags collected" : nil)

                RouteMapView(coordinates: viewModel.coordinates)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))

                EcoStatRow(stats: [
                    EcoStat(label: "Elevation", value: viewModel.elevationText + " m"),
                    EcoStat(label: viewModel.energyLabel, value: viewModel.kcalText),
                    EcoStat(label: "Steps", value: viewModel.stepsText),
                ])

                impactCard

                Button("Done", action: onDone)
                    .buttonStyle(.eco)
            }
            .padding(Eco.Space.l)
            .frame(maxWidth: .infinity)
        }
    }

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            EcoSectionHeader(title: "Impact")
            HStack(spacing: Eco.Space.xl) {
                EcoMetric(label: "Bags", value: String(viewModel.impact.bags))
                EcoMetric(label: "Weight", value: String(format: "%.1f", viewModel.impact.kg), unit: "kg")
                EcoMetric(label: "Items", value: String(viewModel.impact.totalItems))
            }
            let types = WasteType.allCases.filter { viewModel.impact.count(for: $0) > 0 }
            if !types.isEmpty {
                EcoFlowLayout {
                    ForEach(types) { type in
                        EcoChip(title: "\(type.label) \(viewModel.impact.count(for: type))",
                                systemImage: type.systemImage, isSelected: true)
                    }
                }
            }
        }
        .ecoCard()
    }
}
