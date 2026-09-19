import SwiftUI

/// Temporary launch harness for the Activity flow (Person 2 owns the real tab shell).
struct ContentView: View {
    @State private var flow: ActivityViewModel?

    var body: some View {
        VStack(spacing: Eco.Space.xl) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(Eco.onPrimary)
                .frame(width: 112, height: 112)
                .background(Eco.brandGradient, in: Circle())

            VStack(spacing: Eco.Space.s) {
                Text("EcoPlog")
                    .font(.ecoDisplayLarge)
                    .foregroundStyle(Eco.textPrimary)
                Text("Turn every run into a cleanup.")
                    .font(.ecoBodyLarge)
                    .foregroundStyle(Eco.textSecondary)
            }

            Spacer()

            VStack(spacing: Eco.Space.m) {
                if let cleanUp = FakeData.cleanUps.first {
                    Button("Start Clean-Up: \(cleanUp.title)") {
                        flow = AppEnvironment.makeActivityViewModel(context: .cleanUp(cleanUp))
                    }
                    .buttonStyle(.eco)
                }
                Button("Start free activity") {
                    flow = AppEnvironment.makeActivityViewModel(context: .free)
                }
                .buttonStyle(.ecoSecondary)
            }
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
        .fullScreenCover(item: $flow) { viewModel in
            ActivityFlowView(viewModel: viewModel) { flow = nil }
                .ecoTheme()
        }
    }
}

#Preview {
    ContentView()
        .ecoTheme()
}
