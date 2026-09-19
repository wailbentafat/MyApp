import SwiftUI

/// The pre-sign-in screen. Auth is faked (`FakeAuthService`) — this just runs the
/// UI + session flow a real Sign in with Apple button would trigger.
struct WelcomeView: View {
    @Environment(\.appSession) private var appSession

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()

            if let image = FakePhotoStore.shared.loadImage(DemoPhotos.url("crew_beach")) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay {
                        LinearGradient(
                            colors: [Eco.background.opacity(0.35), Eco.background.opacity(0.75), Eco.background],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }
            }

            VStack(spacing: Eco.Space.xl) {
                Spacer()

                Image("HealLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text(AppInfo.tagline)
                    .font(.ecoBodyLarge)
                    .foregroundStyle(Eco.textBody)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await appSession.signInWithApple() }
                } label: {
                    HStack(spacing: Eco.Space.s) {
                        if appSession.isSigningIn {
                            ProgressView().tint(Eco.onButton)
                        } else {
                            Image(systemName: "apple.logo")
                        }
                        Text(appSession.isSigningIn ? "Signing in…" : "Continue with Apple")
                    }
                }
                .buttonStyle(.eco)
                .disabled(appSession.isSigningIn)
                .frame(maxWidth: 300)

                Text("Sign-in and backend are simulated for this build.")
                    .font(.ecoLabelSmall)
                    .foregroundStyle(Eco.textHint)
            }
            .padding(Eco.Space.l)
        }
    }
}

#Preview {
    WelcomeView()
        .ecoTheme()
}
