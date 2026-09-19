import SwiftUI

/// Live recording screen (Strava layout: map, big time, distance | pace, round controls).
struct RecordingView: View {
    let viewModel: ActivityViewModel

    var body: some View {
        VStack(spacing: 0) {
            RouteMapView(coordinates: viewModel.coordinates, followsLatest: true)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) { statusPill.padding(.top, Eco.Space.l) }

            VStack(spacing: Eco.Space.l) {
                EcoMetric(label: "Time", value: viewModel.timeText, size: .hero)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top) {
                    EcoMetric(label: "Distance", value: viewModel.distanceValueText, unit: "km")
                    Spacer()
                    EcoMetric(label: "Pace", value: viewModel.paceText, unit: "/km")
                    Spacer()
                    EcoMetric(label: "Kcal", value: viewModel.kcalText, unit: "est.")
                }

                HStack(alignment: .top) {
                    EcoMetric(label: "Heart rate", value: viewModel.heartRateText, unit: "bpm")
                    Spacer()
                    EcoMetric(label: "Steps", value: viewModel.stepsText)
                    Spacer()
                    EcoMetric(label: "Bags", value: String(viewModel.impact.bags))
                }

                controls
            }
            .padding(Eco.Space.l)
            .padding(.bottom, Eco.Space.s)
            .background(Eco.background)
        }
    }

    private var statusPill: some View {
        Text(viewModel.isPaused ? "PAUSED" : "RECORDING")
            .font(.ecoLabelSmall)
            .tracking(1)
            .foregroundStyle(viewModel.isPaused ? Eco.warning : Eco.primary)
            .padding(.horizontal, Eco.Space.m)
            .padding(.vertical, Eco.Space.xs + 2)
            .background(Eco.surface, in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: Eco.Space.xl) {
            // +1 bag: big and glove-friendly.
            Button {
                viewModel.addBag()
            } label: {
                VStack(spacing: 2) {
                    EcoSymbol("trash.fill", size: 24)
                    Text("+1 bag").font(.ecoLabelSmall)
                }
            }
            .buttonStyle(.ecoRound(size: 72, filled: false))
            .accessibilityLabel("Add a bag")

            if viewModel.isPaused {
                Button("Resume", action: viewModel.resume)
                    .buttonStyle(.ecoRound(size: 96))
                Button("Finish", action: viewModel.finish)
                    .buttonStyle(.ecoRound(size: 72, filled: false, tint: Eco.error))
            } else {
                Button {
                    viewModel.pause()
                } label: {
                    EcoSymbol("pause.fill", size: 32)
                }
                .buttonStyle(.ecoRound(size: 96))
                .accessibilityLabel("Pause")

                // Ghost-camera After photo arrives in Phase 5.
                Button {} label: { EcoSymbol("camera.fill", size: 26) }
                    .buttonStyle(.ecoRound(size: 72, filled: false))
                    .disabled(true)
                    .opacity(0.5)
                    .accessibilityLabel("Take After photo (coming soon)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
