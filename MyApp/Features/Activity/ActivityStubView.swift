import SwiftUI

/// TEMPORARY placeholder for P1's real Activity module (session state machine,
/// CoreLocation route tracking, HealthKit, Live Activity, ghost camera, Reel —
/// see `docs/TEAM_PLAN.md` §7). It exists so P2's pipeline — RSVP → notify →
/// "Start Activity" → upload → Feed — is demoable end to end before that work
/// lands. It conforms to the same contracts P1's real flow will use
/// (`ActivityRepository.upload`, `CleanUpRepository.complete`), so replacing this
/// file with the real flow shouldn't change anything outside `Features/Activity`.
struct ActivityStubView: View {
    let cleanUp: CleanUp
    /// Called with the finished (fake) Activity once "Finish (Demo)" completes.
    var onFinished: (Activity) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSession) private var appSession
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: Eco.Space.xl) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Eco.primary)

            VStack(spacing: Eco.Space.s) {
                Text("Activity tracking")
                    .font(.ecoHeadlineMedium)
                    .foregroundStyle(Eco.textPrimary)
                Text("P1's GPS + HealthKit + ghost-camera flow isn't wired up yet. This placeholder simulates a finished session so the rest of the app — upload, Feed, sharing — can be demoed today.")
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Eco.Space.xl)

            HStack(spacing: Eco.Space.m) {
                EcoStatTile(value: "2.3 km", label: "Distance", systemImage: "figure.walk")
                EcoStatTile(value: "\(cleanUp.estimatedBags)", label: "Bags", systemImage: "bag.fill")
                EcoStatTile(value: "180", label: "kcal", systemImage: "flame.fill")
            }

            Spacer()

            Button {
                Task { await finish() }
            } label: {
                if isFinishing {
                    ProgressView().tint(Eco.onPrimary)
                } else {
                    Text("Finish (Demo)")
                }
            }
            .buttonStyle(.eco)
            .disabled(isFinishing)

            Button("Cancel") { dismiss() }
                .buttonStyle(.ecoSecondary)
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
        .interactiveDismissDisabled(isFinishing)
    }

    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }

        guard let user = appSession.currentUser else { return }
        try? await Task.sleep(for: .milliseconds(700))

        let activity = Activity(
            id: UUID(),
            userId: user.id,
            cleanUpId: cleanUp.id,
            startedAt: Date().addingTimeInterval(-32 * 60),
            endedAt: Date(),
            route: [],
            distance: Double.random(in: 1200...3400),
            duration: 32 * 60,
            elevation: Double.random(in: 5...40),
            kcal: Double.random(in: 140...320),
            avgHR: Bool.random() ? Double.random(in: 100...140) : nil,
            steps: Int.random(in: 2200...4800),
            impactLog: ImpactLog(bags: cleanUp.estimatedBags, kg: Double(cleanUp.estimatedBags) * 3.2, itemCounts: [:]),
            afterPhotoURL: cleanUp.beforePhotoURL,
            reelURL: nil
        )

        onFinished(activity)
        dismiss()
    }
}

#Preview {
    ActivityStubView(cleanUp: Fixtures.seedCleanUps()[0], onFinished: { _ in })
        .ecoTheme()
}
