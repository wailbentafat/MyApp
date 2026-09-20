import SwiftUI

/// Home tab (Strava "Accueil"): top bar, streak, Clean-Ups near you, community feed.
struct HomeView: View {
    @Binding var selectedTab: AppTab
    var onSpot: () -> Void
    var onRecord: () -> Void

    @Environment(\.feedService) private var feedService
    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.shareService) private var shareService
    @Environment(\.appSession) private var appSession
    @Environment(\.inboxService) private var inboxService

    @State private var viewModel: HomeViewModel?
    @State private var openedCleanUp: CleanUp?
    @State private var showNotifications = false

    var body: some View {
        VStack(spacing: 0) {
            EcoTopBar(title: AppInfo.name) {
                EcoCircleButton(systemImage: "camera.viewfinder", label: "Spot pollution", action: onSpot)
            } trailing: {
                EcoCircleButton(systemImage: "bell", label: "Notifications", badge: (viewModel?.unreadCount ?? 0) > 0) {
                    showNotifications = true
                }
            }

            if let viewModel {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Eco.Space.xl) {
                        StreakCard(badge: viewModel.streakBadge, message: viewModel.streakTitle, actionTitle: "Start", onAction: onRecord)

                        nearby(viewModel)

                        VStack(alignment: .leading, spacing: Eco.Space.m) {
                            Text("Community").font(.ecoHeadlineMedium).foregroundStyle(Eco.textPrimary)
                            if viewModel.posts.isEmpty && !viewModel.isLoading {
                                ContentUnavailableView("No activity yet", systemImage: "figure.walk.circle",
                                                       description: Text("Finished Clean-Ups will show up here."))
                            }
                            ForEach(viewModel.posts) { post in
                                ActivityPostCard(post: post,
                                                 onKudos: { await viewModel.toggleKudos(post) },
                                                 onShare: { await share(post) })
                            }
                        }
                    }
                    .padding(.horizontal, Eco.Space.l)
                    .padding(.bottom, Eco.Space.xl)
                }
                .refreshable { await viewModel.load() }
            } else {
                Spacer()
            }
        }
        .ecoScreenBackground()
        .task {
            guard viewModel == nil, let user = appSession.currentUser else { return }
            let model = HomeViewModel(user: user, feed: feedService, cleanUps: cleanUpRepository, activities: activityRepository, inbox: inboxService)
            viewModel = model
            await model.load()
        }
        .fullScreenCover(isPresented: $showNotifications, onDismiss: {
            Task { await viewModel?.refreshUnread() }
        }) {
            NotificationsView(onClose: { showNotifications = false })
                .ecoTheme()
        }
        .sheet(item: $openedCleanUp) { cleanUp in
            NavigationStack { CleanUpDetailView(cleanUp: cleanUp, selectedTab: $selectedTab) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func nearby(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Clean-Ups near you").font(.ecoHeadlineMedium).foregroundStyle(Eco.textPrimary)
                Spacer()
                Button("See all") { selectedTab = .cleanUps }
                    .font(.ecoLabelLarge)
                    .foregroundStyle(Eco.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Eco.Space.m) {
                    ForEach(viewModel.nearbyCleanUps) { cleanUp in
                        CleanUpCard(
                            cleanUp: cleanUp,
                            subtitle: viewModel.distanceText(to: cleanUp),
                            rsvpTitle: viewModel.rsvpTitle(for: cleanUp),
                            isGoing: viewModel.isAttending(cleanUp),
                            onOpen: { openedCleanUp = cleanUp },
                            onRSVP: { Task { await viewModel.toggleRSVP(cleanUp) } }
                        )
                        .frame(width: 300)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func share(_ post: FeedPost) async {
        let image = FakePhotoStore.shared.loadImage(post.afterPhotoURL ?? post.beforePhotoURL)
        _ = await shareService.shareToInstagramStory(
            image: image, videoURL: nil,
            caption: "\(post.cleanUpTitle) — \(post.bags) bags, \(String(format: "%.1f", post.distanceKm)) km with \(AppInfo.name) 🌱"
        )
    }
}
