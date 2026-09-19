import SwiftUI

struct CleanUpDetailView: View {
    let cleanUp: CleanUp
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.feedService) private var feedService
    @Environment(\.appSession) private var appSession
    @Environment(\.dismiss) private var dismiss

    @State private var isJoining = false
    @State private var showActivitySheet = false
    @State private var committedGear: Set<String> = []

    private var currentUserId: UUID? { appSession.currentUser?.id }
    private var isAttending: Bool {
        guard let currentUserId else { return false }
        return cleanUp.attendeeIds.contains(currentUserId)
    }
    private var isHost: Bool { cleanUp.hostId == currentUserId }

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
                        Label(hazardMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.ecoBodySmall)
                            .foregroundStyle(cleanUp.hazard == .hazardous ? Eco.error : Eco.warning)
                    }
                }

                HStack {
                    ForEach(cleanUp.wasteTypes) { type in
                        EcoChip(title: type.label, systemImage: type.systemImage)
                    }
                }

                HStack(spacing: Eco.Space.m) {
                    EcoStatTile(value: "\(cleanUp.estimatedBags)", label: "Bags", systemImage: "bag.fill")
                    EcoStatTile(value: cleanUp.severity.label, label: "Severity", systemImage: "gauge.with.dots.needle.67percent")
                    EcoStatTile(value: attendeeLabel, label: "Attendees", systemImage: "person.2.fill")
                }

                gearSection

                if let startsAt = cleanUp.startsAt {
                    Label(startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textBody)
                }

                actions
            }
            .padding(Eco.Space.l)
        }
        .ecoScreenBackground()
        .navigationTitle("Clean-Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            ActivityStubView(cleanUp: cleanUp, onFinished: handleFinishedActivity)
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
                    .overlay(Image(systemName: "photo.fill").font(.largeTitle).foregroundStyle(Eco.textHint))
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))
    }

    private var attendeeLabel: String {
        if let capacity = cleanUp.capacity {
            return "\(cleanUp.attendeeCount)/\(capacity)"
        }
        return "\(cleanUp.attendeeCount)"
    }

    private var gearSection: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            EcoSectionHeader(title: "Gear checklist")
            VStack(spacing: Eco.Space.s) {
                ForEach(cleanUp.gear) { item in
                    Button {
                        toggleGear(item.name)
                    } label: {
                        HStack {
                            Image(systemName: committedGear.contains(item.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(committedGear.contains(item.name) ? Eco.primary : Eco.textHint)
                            Text(item.name)
                                .font(.ecoBodyMedium)
                                .foregroundStyle(Eco.textBody)
                            Spacer()
                            Text("\(item.committedCount + (committedGear.contains(item.name) ? 1 : 0)) bringing")
                                .font(.ecoLabelSmall)
                                .foregroundStyle(Eco.textHint)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .ecoCard()
        }
    }

    private var actions: some View {
        VStack(spacing: Eco.Space.m) {
            if cleanUp.status != .done {
                Button {
                    Task { await toggleRSVP() }
                } label: {
                    if isJoining {
                        ProgressView().tint(isAttending ? Eco.primary : Eco.onPrimary)
                    } else {
                        Text(isAttending ? "Leave Clean-Up" : (cleanUp.isFull ? "Full" : "RSVP — I'm in"))
                    }
                }
                .buttonStyle(isAttending ? .ecoSecondary : .eco)
                .disabled(isJoining || (!isAttending && cleanUp.isFull))
            }

            if isAttending || isHost, cleanUp.status == .open || cleanUp.status == .scheduled || cleanUp.status == .live {
                Button {
                    showActivitySheet = true
                } label: {
                    Label("Start Activity", systemImage: "play.fill")
                }
                .buttonStyle(.ecoSecondary)
            }
        }
    }

    private func toggleGear(_ name: String) {
        if committedGear.contains(name) {
            committedGear.remove(name)
        } else {
            committedGear.insert(name)
        }
    }

    private func toggleRSVP() async {
        guard let userId = currentUserId else { return }
        isJoining = true
        defer { isJoining = false }
        _ = try? await cleanUpRepository.setRSVP(cleanUpId: cleanUp.id, userId: userId, joining: !isAttending)
    }

    private func handleFinishedActivity(_ activity: Activity) {
        Task {
            try? await activityRepository.upload(activity)
            let updated = (try? await cleanUpRepository.complete(cleanUpId: cleanUp.id, activityId: activity.id)) ?? cleanUp
            if let user = appSession.currentUser {
                await feedService.publish(activity: activity, cleanUp: updated, author: user)
            }
            selectedTab = .feed
            dismiss()
        }
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
