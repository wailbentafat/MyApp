import SwiftUI

/// The pre-sign-in screen. Auth is faked (`FakeAuthService`) — this just runs the
/// UI + session flow a real Sign in with Apple button would trigger.
struct WelcomeView: View {
    @Environment(\.appSession) private var appSession

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

            Button {
                Task { await appSession.signInWithApple() }
            } label: {
                HStack(spacing: Eco.Space.s) {
                    if appSession.isSigningIn {
                        ProgressView().tint(Eco.onPrimary)
                    } else {
                        Image(systemName: "apple.logo")
                    }
                    Text(appSession.isSigningIn ? "Signing in…" : "Sign in with Apple")
                }
            }
            .buttonStyle(.eco)
            .disabled(appSession.isSigningIn)

            Text("Sign-in and backend are simulated for this build.")
                .font(.ecoLabelSmall)
                .foregroundStyle(Eco.textHint)
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
    }
}

#Preview {
    WelcomeView()
        .ecoTheme()
}
