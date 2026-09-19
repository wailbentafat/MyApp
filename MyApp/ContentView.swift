import SwiftUI

struct ContentView: View {
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

            HStack(spacing: Eco.Space.m) {
                EcoStatTile(value: "5.2 km", label: "Distance", systemImage: "figure.walk")
                EcoStatTile(value: "312", label: "kcal", systemImage: "flame.fill")
            }

            Spacer()

            Button("Start Plog") {}
                .buttonStyle(.eco)
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
    }
}

#Preview {
    ContentView()
        .ecoTheme()
}
