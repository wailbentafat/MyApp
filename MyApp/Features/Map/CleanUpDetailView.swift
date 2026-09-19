import SwiftUI

/// Clean-Up detail sheet. Owns only the view model; RSVP, gear and finishing logic live in `CleanUpDetailViewModel`.
struct CleanUpDetailView: View {
    let cleanUp: CleanUp
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.feedService) private var feedService
    @Environment(\.appSession) private var appSession
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CleanUpDetailViewModel?
    @State private var showActivity = false

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                DetailContent(viewModel: viewModel, onStartActivity: { showActivity = true })
            }
        }
        .navigationTitle("Clean-Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            guard viewModel == nil else { return }
            let coordinator = ActivityCompletionCoordinator(
                activities: activityRepository, cleanUps: cleanUpRepository, feed: feedService
            )
            viewModel = CleanUpDetailViewModel(
                cleanUp: cleanUp, user: appSession.currentUser,
                repository: cleanUpRepository, completion: coordinator
            )
        }
        .onChange(of: cleanUp) { _, fresh in viewModel?.update(fresh) }
        .fullScreenCover(isPresented: $showActivity) {
            ActivityFlowLauncher(cleanUp: viewModel?.cleanUp ?? cleanUp) { activity in
                Task {
                    await viewModel?.finish(activity)
                    selectedTab = .home
                    dismiss()
                }
            }
            .ecoTheme()
        }
    }
}

private struct DetailContent: View {
    let viewModel: CleanUpDetailViewModel
    var onStartActivity: () -> Void

    private var cleanUp: CleanUp { viewModel.cleanUp }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                photo

                VStack(alignment: .leading, spacing: Eco.Space.s) {
                    HStack {
                        Text(cleanUp.title)
                            .font(.ecoHeadlineMedium)
                            .foregroundStyle(Eco.textPrimary)
                        Spacer()
                        StatusBadge(status: cleanUp.status)
                    }
                    Text("Hosted by \(cleanUp.hostName)")
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                    if let hazardMessage = cleanUp.hazard.message {
                        EcoLabel(hazardMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.ecoBodySmall)
                            .foregroundStyle(cleanUp.hazard == .hazardous ? Eco.error : Eco.warning)
                    }
                }

                EcoFlowLayout {
                    ForEach(cleanUp.wasteTypes) { type in
                        EcoChip(title: type.label, systemImage: type.systemImage)
                    }
                }

                HStack(spacing: Eco.Space.m) {
                    EcoStatTile(value: "\(cleanUp.estimatedBags)", label: "Bags", systemImage: "bag.fill")
                    EcoStatTile(value: cleanUp.severity.label, label: "Severity", systemImage: "gauge.with.dots.needle.67percent")
                    EcoStatTile(value: viewModel.attendeeLabel, label: "Attendees", systemImage: "person.2.fill")
                }

                gearSection

                if let startsAt = cleanUp.startsAt {
                    EcoLabel(startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textBody)
                }

                actions
            }
            .padding(Eco.Space.l)
        }
    }

    private var photo: some View {
        Group {
            if let image = FakePhotoStore.shared.loadImage(cleanUp.beforePhotoURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Eco.surfaceRaised
                    .overlay(EcoSymbol("photo.fill", size: 40).foregroundStyle(Eco.textHint))
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))
    }

    private var gearSection: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            EcoSectionHeader(title: "Gear checklist")
            VStack(spacing: Eco.Space.m) {
                ForEach(cleanUp.gear) { item in
                    Button {
                        viewModel.toggleGear(item)
                    } label: {
                        HStack {
                            EcoSymbol(viewModel.isCommitted(item) ? "checkmark.circle.fill" : "circle", size: 22)
                                .foregroundStyle(viewModel.isCommitted(item) ? Eco.primary : Eco.textHint)
                            Text(item.name)
                                .font(.ecoBodyMedium)
                                .foregroundStyle(Eco.textBody)
                            Spacer()
                            Text(viewModel.bringingText(for: item))
                                .font(.ecoLabelSmall)
                                .foregroundStyle(Eco.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .ecoCard()
        }
    }

    /// White primary button for the main action, outlined for the secondary one.
    private var actions: some View {
        VStack(spacing: Eco.Space.m) {
            if viewModel.canStartActivity {
                Button(action: onStartActivity) {
                    EcoLabel("Start Activity", systemImage: "play.fill", size: 18, spacing: 8)
                }
                .buttonStyle(.eco)
            }

            if !viewModel.isDone {
                Button {
                    Task { await viewModel.toggleRSVP() }
                } label: {
                    if viewModel.isJoining {
                        ProgressView().tint(viewModel.isAttending ? Eco.buttonFill : Eco.onButton)
                    } else {
                        Text(viewModel.rsvpTitle)
                    }
                }
                .buttonStyle(viewModel.isAttending ? .ecoSecondary : .eco)
                .disabled(viewModel.isRSVPDisabled)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }
}

private struct StatusBadge: View {
    let status: CleanUpStatus

    var body: some View {
        Text(status.label)
            .font(.ecoLabelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, Eco.Space.s)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .open: Eco.primary
        case .scheduled: Eco.info
        case .live: Eco.warning
        case .done: Eco.textHint
        }
    }
}

#Preview {
    NavigationStack {
        CleanUpDetailView(cleanUp: Fixtures.seedCleanUps()[0], selectedTab: .constant(.map))
    }
    .ecoTheme()
}
