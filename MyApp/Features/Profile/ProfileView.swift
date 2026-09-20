import SwiftUI

/// You tab. Owns only the view model; state and logic live in `ProfileViewModel`.
struct ProfileView: View {
    @Environment(\.appSession) private var appSession
    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.demoDataResetter) private var resetter
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                ProfileContent(viewModel: viewModel)
            }
        }
        .navigationTitle("Me")
        .task {
            guard viewModel == nil else { return }
            let model = ProfileViewModel(user: appSession.currentUser, activities: activityRepository, resetter: resetter)
            viewModel = model
            await model.load()
            await model.subscribe()
        }
    }
}

private struct ProfileContent: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.appSession) private var appSession
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                header

                HStack(spacing: Eco.Space.m) {
                    EcoStatTile(value: viewModel.cleanUpsText, label: "Clean-Ups", systemImage: "checkmark.seal.fill")
                    EcoStatTile(value: viewModel.bagsText, label: "Bags", systemImage: "bag.fill")
                    EcoStatTile(value: viewModel.distanceText, label: "Distance", systemImage: "figure.walk")
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Impact equivalents")
                    Text(viewModel.bottlesText)
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textBody)
                        .ecoCard()
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Badges")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Eco.Space.m) {
                            ForEach(viewModel.badges) { BadgeTile(badge: $0) }
                        }
                    }
                }

                activities

                settings
            }
            .padding(Eco.Space.l)
        }
        .confirmationDialog("Reset all demo data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { Task { await viewModel.resetDemoData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your activities, RSVPs, comments and notifications go back to the sample data.")
        }
        .fullScreenCover(item: $viewModel.selectedActivity) { activity in
            ActivityShareLauncher(activity: activity, onClose: { viewModel.closePreview() })
                .ecoTheme()
        }
    }

    private var header: some View {
        HStack(spacing: Eco.Space.m) {
            EcoAvatar(name: viewModel.displayName, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayName)
                    .font(.ecoHeadlineSmall)
                    .foregroundStyle(Eco.textPrimary)
                Text("Healer")
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
            Spacer()
        }
    }

    private var activities: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            EcoSectionHeader(title: "Activities")
            VStack(spacing: Eco.Space.s) {
                ForEach(viewModel.rows) { row in
                    Button { viewModel.open(row) } label: { ActivityRow(row: row) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            EcoSectionHeader(title: "Settings")
            VStack(spacing: 0) {
                Toggle(
                    "Nearby Clean-Up notifications",
                    isOn: Binding(
                        get: { appSession.notificationsEnabled },
                        set: { appSession.setNotificationsEnabled($0) }
                    )
                )
                .font(.ecoBodyMedium)
                .foregroundStyle(Eco.textBody)
                .tint(Eco.primary)
                .padding(.vertical, Eco.Space.s)

                Divider().overlay(Eco.border)

                Button {
                    confirmReset = true
                } label: {
                    HStack {
                        Text(viewModel.isResetting ? "Resetting…" : "Reset demo data")
                        Spacer()
                    }
                }
                .foregroundStyle(Eco.textBody)
                .font(.ecoBodyMedium)
                .padding(.vertical, Eco.Space.s)
                .disabled(viewModel.isResetting)

                Divider().overlay(Eco.border)

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
}

/// One activity: thumbnail, title, date, stats, and a share chevron. Tapping opens the share preview.
private struct ActivityRow: View {
    let row: ProfileViewModel.Row

    var body: some View {
        HStack(spacing: Eco.Space.m) {
            Group {
                if let image = FakePhotoStore.shared.loadImage(row.photoURL) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Eco.surfaceRaised
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.ecoTitleMedium)
                    .foregroundStyle(Eco.textPrimary)
                    .lineLimit(1)
                Text(row.dateText)
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
                Text(row.statsText)
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textBody)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            EcoSymbol("chevron.right", size: 16)
                .foregroundStyle(Eco.textSecondary)
        }
        .padding(Eco.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
        .contentShape(Rectangle())
    }
}

private struct BadgeTile: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: Eco.Space.s) {
            EcoSymbol(badge.systemImage, size: 24)
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

#Preview {
    NavigationStack { ProfileView() }
        .ecoTheme()
}
