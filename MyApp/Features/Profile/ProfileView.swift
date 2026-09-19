import SwiftUI

struct ProfileView: View {
    @Environment(\.appSession) private var appSession
    @Environment(\.activityRepository) private var activityRepository

    @State private var history: [Activity] = []
    private let badges = Fixtures.seedBadges()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                header

                HStack(spacing: Eco.Space.m) {
                    EcoStatTile(value: "\(appSession.currentUser?.totals.cleanUpsJoined ?? 0)", label: "Clean-Ups", systemImage: "checkmark.seal.fill")
                    EcoStatTile(value: "\(appSession.currentUser?.totals.bagsCollected ?? 0)", label: "Bags", systemImage: "bag.fill")
                    EcoStatTile(value: String(format: "%.0f km", appSession.currentUser?.totals.distanceKm ?? 0), label: "Distance", systemImage: "figure.walk")
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Impact equivalents")
                    Text("≈ \((appSession.currentUser?.totals.bagsCollected ?? 0) * 45) plastic bottles kept out of waterways")
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textBody)
                        .ecoCard()
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Badges")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Eco.Space.m) {
                            ForEach(badges) { badge in
                                BadgeTile(badge: badge)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "History")
                    if history.isEmpty {
                        Text("No finished activities yet.")
                            .font(.ecoBodySmall)
                            .foregroundStyle(Eco.textHint)
                    } else {
                        VStack(spacing: Eco.Space.s) {
                            ForEach(history) { activity in
                                HistoryRow(activity: activity)
                            }
                        }
                        .ecoCard()
                    }
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Settings")
                    VStack(spacing: 0) {
                        Toggle(
                            "Nearby Clean-Up notifications",
                            isOn: Binding(
                                get: { appSession.notificationsEnabled },
                                set: { appSession.notificationsEnabled = $0 }
                            )
                        )
                            .font(.ecoBodyMedium)
                            .foregroundStyle(Eco.textBody)
                            .tint(Eco.primary)
                            .padding(.vertical, Eco.Space.s)

                        Divider().background(Eco.border)

                        Button(role: .destructive) {
                            Task { await appSession.signOut() }
                        } label: {
                            HStack {
                                Text("Sign out")
                                Spacer()
                                EcoSymbol("rectangle.portrait.and.arrow.right")
                            }
                        }
                        .foregroundStyle(Eco.error)
                        .font(.ecoBodyMedium)
                        .padding(.vertical, Eco.Space.s)
                    }
                    .ecoCard()
                }
            }
            .padding(Eco.Space.l)
        }
        .ecoScreenBackground()
        .navigationTitle("Me")
        .task { await loadHistory() }
    }

    private var header: some View {
        HStack(spacing: Eco.Space.m) {
            EcoAvatar(name: appSession.currentUser?.name ?? "hɛal", size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(appSession.currentUser?.name ?? "—")
                    .font(.ecoHeadlineSmall)
                    .foregroundStyle(Eco.textPrimary)
                Text("Healer")
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
            Spacer()
        }
    }

    private func loadHistory() async {
        guard let userId = appSession.currentUser?.id else { return }
        history = (try? await activityRepository.history(userId: userId)) ?? []
    }
}

private struct BadgeTile: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: Eco.Space.s) {
            EcoSymbol(badge.systemImage)
                .font(.title2)
                .foregroundStyle(badge.isEarned ? Eco.onPrimary : Eco.textHint)
                .frame(width: 56, height: 56)
                .background(badge.isEarned ? Eco.primary : Eco.surfaceRaised, in: Circle())
            Text(badge.title)
                .font(.ecoLabelSmall)
                .foregroundStyle(badge.isEarned ? Eco.textPrimary : Eco.textHint)
                .multilineTextAlignment(.center)
                .frame(width: 76)
        }
    }
}

private struct HistoryRow: View {
    let activity: Activity

    var body: some View {
        HStack {
            EcoSymbol("figure.run")
                .foregroundStyle(Eco.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textBody)
                Text(String(format: "%.1f km · %.0f kcal · %d bags", activity.distance / 1000, activity.kcal, activity.impactLog.bags))
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, Eco.Space.xs)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .ecoTheme()
}
