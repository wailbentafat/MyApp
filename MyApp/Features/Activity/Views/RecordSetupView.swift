import MapKit
import SwiftUI

/// Strava "Record" screen: map on top, context, and a big START button.
struct RecordSetupView: View {
    let viewModel: ActivityViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                background
                Button(action: onClose) {
                    EcoSymbol("xmark", size: 18)
                        .foregroundStyle(Eco.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Eco.surface, in: Circle())
                }
                .padding(Eco.Space.l)
                .accessibilityLabel("Close")
            }

            VStack(spacing: Eco.Space.l) {
                if let cleanUp = viewModel.context.cleanUp {
                    CleanUpBanner(cleanUp: cleanUp)
                } else {
                    Text("Free activity")
                        .font(.ecoHeadlineSmall)
                        .foregroundStyle(Eco.textPrimary)
                    Text("Track any walk or run and log what you pick up.")
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button("START", action: viewModel.start)
                    .buttonStyle(.ecoRound(size: 104))
                    .accessibilityLabel("Start activity")
                    .padding(.top, Eco.Space.s)
            }
            .padding(Eco.Space.l)
            .padding(.bottom, Eco.Space.l)
            .frame(maxWidth: .infinity)
            .background(Eco.background)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let cleanUp = viewModel.context.cleanUp {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: cleanUp.coordinate.clLocationCoordinate, distance: 900))) {
                Marker(cleanUp.title, systemImage: "leaf.fill", coordinate: cleanUp.coordinate.clLocationCoordinate)
                    .tint(Eco.primary)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        } else {
            Map(initialPosition: .userLocation(fallback: .automatic))
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        }
    }
}

private struct CleanUpBanner: View {
    let cleanUp: CleanUp

    var body: some View {
        VStack(alignment: .leading, spacing: Eco.Space.s) {
            EcoLabel(cleanUp.title, systemImage: "leaf.fill", size: 20, spacing: 8)
                .font(.ecoHeadlineSmall)
                .foregroundStyle(Eco.textPrimary)
            if !cleanUp.wasteTypes.isEmpty {
                EcoFlowLayout {
                    ForEach(cleanUp.wasteTypes) { EcoChip(title: $0.label, systemImage: $0.systemImage) }
                }
            }
            if !cleanUp.gear.isEmpty {
                Text("Bring: " + cleanUp.gear.map(\.name).joined(separator: ", "))
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
        }
        .ecoCard()
    }
}
