import SwiftUI

/// Strava-style activity post: author, title, stats row, impact banner, Before/After media, actions.
struct ActivityPostCard: View {
    let post: FeedPost
    var onKudos: () async -> Void
    var onShare: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            header

            Text(post.cleanUpTitle)
                .font(.ecoHeadlineMedium)
                .foregroundStyle(Eco.textPrimary)

            EcoStatRow(stats: [
                EcoStat(label: "Distance", value: String(format: "%.1f km", post.distanceKm)),
                EcoStat(label: "Bags", value: "\(post.bags)"),
                EcoStat(label: "Energy", value: "\(Int(post.kcal)) kcal"),
            ])

            EcoBanner(
                systemImage: "leaf.circle.fill",
                title: "≈ \(post.bags * 45) plastic bottles kept out of waterways",
                subtitle: "Clean-Up completed"
            )

            HStack(spacing: Eco.Space.s) {
                photoTile(url: post.beforePhotoURL, label: "Before")
                photoTile(url: post.afterPhotoURL, label: "After")
            }

            actions
        }
        .padding(.vertical, Eco.Space.l)
        .padding(.horizontal, Eco.Space.l)
        .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
    }

    private var header: some View {
        HStack(spacing: Eco.Space.m) {
            EcoAvatar(name: post.authorName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(.ecoTitleMedium)
                    .foregroundStyle(Eco.textPrimary)
                Text(post.createdAt.formatted(.relative(presentation: .named)))
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        HStack {
            Button { Task { await onKudos() } } label: {
                EcoLabel("\(post.kudosCount)", systemImage: "hand.thumbsup", size: 20, spacing: 6)
            }
            .foregroundStyle(post.kudosGivenByMe ? Eco.primary : Eco.textSecondary)
            .accessibilityLabel("Eco-Boost")

            Spacer()

            Button { Task { await onShare() } } label: {
                EcoLabel("Share", systemImage: "square.and.arrow.up", size: 20, spacing: 6)
            }
            .foregroundStyle(Eco.textSecondary)
        }
        .font(.ecoLabelLarge)
    }

    private func photoTile(url: URL?, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = FakePhotoStore.shared.loadImage(url) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Eco.surfaceRaised
                EcoSymbol("photo", size: 28).foregroundStyle(Eco.textHint).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(label)
                .font(.ecoLabelSmall)
                .foregroundStyle(.white)
                .padding(.horizontal, Eco.Space.s)
                .padding(.vertical, 3)
                .glassEffect(.regular, in: .capsule)
                .padding(6)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.field))
    }
}
