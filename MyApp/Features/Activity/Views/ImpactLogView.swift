import SwiftUI

/// After finishing: name the activity, log what was collected, save.
struct ImpactLogView: View {
    @Bindable var viewModel: ActivityViewModel
    var onDiscard: () -> Void

    @State private var confirmDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                Text("Nice work!")
                    .font(.ecoDisplaySmall)
                    .foregroundStyle(Eco.textPrimary)

                TextField("Name your activity", text: $viewModel.title)
                    .textFieldStyle(EcoTextFieldStyle())

                HStack(spacing: Eco.Space.m) {
                    EcoStatTile(value: viewModel.distanceValueText + " km", label: "Distance", systemImage: "figure.walk")
                    EcoStatTile(value: viewModel.timeText, label: "Time", systemImage: "timer")
                }

                EcoSectionHeader(title: "What did you collect?")

                VStack(spacing: Eco.Space.m) {
                    stepperRow(title: "Bags", value: String(viewModel.impact.bags),
                               minus: viewModel.removeBag, plus: viewModel.addBag)
                    stepperRow(title: "Weight", value: String(format: "%.1f kg", viewModel.impact.kg),
                               minus: { viewModel.adjustKg(by: -0.5) }, plus: { viewModel.adjustKg(by: 0.5) })
                }
                .ecoCard()

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    Text("Items").font(.ecoTitleMedium).foregroundStyle(Eco.textSecondary)
                    ForEach(WasteCategory.allCases, id: \.self) { category in
                        stepperRow(
                            title: category.label,
                            value: String(viewModel.impact.items[category] ?? 0),
                            systemImage: category.systemImage,
                            minus: { viewModel.decrement(category) },
                            plus: { viewModel.increment(category) }
                        )
                    }
                }
                .ecoCard()

                if let message = viewModel.errorMessage {
                    Text(message).font(.ecoBodySmall).foregroundStyle(Eco.error)
                }

                VStack(spacing: Eco.Space.m) {
                    Button(viewModel.isSaving ? "Saving…" : "Save activity") {
                        Task { await viewModel.save() }
                    }
                    .buttonStyle(.eco)
                    .disabled(viewModel.isSaving)

                    Button("Discard") { confirmDiscard = true }
                        .buttonStyle(.ecoSecondary)
                }
            }
            .padding(Eco.Space.l)
        }
        .confirmationDialog("Discard this activity?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                viewModel.discard()
                onDiscard()
            }
            Button("Keep editing", role: .cancel) {}
        }
    }

    private func stepperRow(title: String, value: String, systemImage: String? = nil,
                            minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Eco.primary).frame(width: 28)
            }
            Text(title).font(.ecoBodyLarge).foregroundStyle(Eco.textBody)
            Spacer()
            Button(action: minus) { Image(systemName: "minus") }
                .buttonStyle(.ecoRound(size: 40, filled: false))
                .accessibilityLabel("Remove \(title)")
            Text(value)
                .font(.ecoTitleLarge)
                .monospacedDigit()
                .foregroundStyle(Eco.textPrimary)
                .frame(minWidth: 52)
            Button(action: plus) { Image(systemName: "plus") }
                .buttonStyle(.ecoRound(size: 40))
                .accessibilityLabel("Add \(title)")
        }
    }
}
