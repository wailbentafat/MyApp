import SwiftUI

struct SpotAnalyzingView: View {
    private let steps = [
        "Checking image quality…",
        "Detecting waste on-device…",
        "Estimating volume and severity…",
        "Matching gear…",
    ]
    @State private var stepIndex = 0

    var body: some View {
        VStack(spacing: Eco.Space.xl) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(Eco.primary)

            VStack(spacing: Eco.Space.s) {
                Text("Analysing photo")
                    .font(.ecoHeadlineMedium)
                    .foregroundStyle(Eco.textPrimary)
                Text(steps[stepIndex])
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textSecondary)
                    .contentTransition(.opacity)
                    .id(stepIndex)
            }

            Spacer()
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
        .task {
            for index in steps.indices {
                stepIndex = index
                try? await Task.sleep(for: .milliseconds(550))
            }
        }
    }
}

#Preview {
    SpotAnalyzingView().ecoTheme()
}
