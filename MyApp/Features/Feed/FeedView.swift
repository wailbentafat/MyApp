import SwiftUI

struct FeedView: View {
    @Environment(\.feedService) private var feedService
    @Environment(\.appSession) private var appSession
    @Environment(\.shareService) private var shareService

    @State private var posts: [FeedPost] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Eco.Space.l) {
                if posts.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "figure.run.circle",
                        description: Text("Finished Clean-Ups from the community will show up here.")
                    )
                    .padding(.top, Eco.Space.xxl)
                } else {
                    ForEach(posts) { post in
                        FeedPostCard(post: post, onKudos: { await toggleKudos(post) }, onShare: { await share(post) })
                    }
                }
            }
            .padding(Eco.Space.l)
        }
        .refreshable { await load() }
        .navigationTitle("Feed")
        .ecoScreenBackground()
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        posts = (try? await feedService.recentPosts()) ?? []
    }

    private func toggleKudos(_ post: FeedPost) async {
        guard let userId = appSession.currentUser?.id else { return }
        if let updated = try? await feedService.toggleKudos(postId: post.id, userId: userId),
           let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updated
        }
    }

    private func share(_ post: FeedPost) async {
        let image = FakePhotoStore.shared.loadImage(post.afterPhotoURL ?? post.beforePhotoURL)
        _ = await shareService.shareToInstagramStory(
            image: image,
            videoURL: nil,
            caption: "\(post.cleanUpTitle) — \(post.bags) bags, \(String(format: "%.1f", post.distanceKm)) km with \(AppInfo.name) 🌱"
        )
    }
}

private struct FeedPostCard: View {
    let post: FeedPost
    var onKudos: () async -> Void
    var onShare: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            HStack(spacing: Eco.Space.s) {
                EcoSymbol(post.authorAvatarSystemImage)
                    .font(.title3)
                    .foregroundStyle(Eco.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.ecoTitleMedium)
                        .foregroundStyle(Eco.textPrimary)
                    Text(post.cleanUpTitle)
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                }
                Spacer()
                Text(post.createdAt.formatted(.relative(presentation: .named)))
                    .font(.ecoLabelSmall)
                    .foregroundStyle(Eco.textHint)
            }

            beforeAfter

            HStack(spacing: Eco.Space.m) {
                EcoStatTile(value: String(format: "%.1f km", post.distanceKm), label: "Distance", systemImage: "figure.walk")
                EcoStatTile(value: "\(Int(post.kcal))", label: "kcal", systemImage: "flame.fill")
                EcoStatTile(value: "\(post.bags)", label: "Bags", systemImage: "bag.fill")
            }

            HStack(spacing: Eco.Space.l) {
                Button {
                    Task { await onKudos() }
                } label: {
                    EcoLabel("\(post.kudosCount)", systemImage: post.kudosGivenByMe ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .foregroundStyle(post.kudosGivenByMe ? Eco.primary : Eco.textSecondary)

                Button {
                    Task { await onShare() }
                } label: {
                    EcoLabel("Share", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(Eco.textSecondary)

                Spacer()
            }
            .font(.ecoLabelMedium)
        }
        .ecoCard()
    }

    private var beforeAfter: some View {
        HStack(spacing: Eco.Space.s) {
            photoTile(url: post.beforePhotoURL, label: "Before")
            photoTile(url: post.afterPhotoURL, label: "After")
        }
    }

    private func photoTile(url: URL?, label: String) -> some View {
        EcoPhoto(image: FakePhotoStore.shared.loadImage(url), height: 120)
            .overlay(alignment: .bottomLeading) {
                Text(label)
                    .font(.ecoLabelSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Eco.Space.s)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(6)
            }
    }
}

#Preview {
    NavigationStack { FeedView() }
        .ecoTheme()
}
