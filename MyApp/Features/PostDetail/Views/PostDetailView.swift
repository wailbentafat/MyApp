import SwiftUI

/// Post screen: media pager, stats, impact, Eco-Boost, comments and a composer. Owns only the view model.
struct PostDetailView: View {
    let activityId: UUID
    var highlightCommentID: UUID?

    @Environment(\.appSession) private var appSession
    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.feedService) private var feedService
    @Environment(\.socialService) private var socialService
    @State private var viewModel: PostDetailViewModel?

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                PostDetailContent(viewModel: viewModel)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil, let user = appSession.currentUser else { return }
            let model = PostDetailViewModel(
                activityId: activityId, highlightCommentID: highlightCommentID, user: user,
                activities: activityRepository, feed: feedService, social: socialService
            )
            viewModel = model
            await model.load()
        }
    }
}

private struct PostDetailContent: View {
    @Bindable var viewModel: PostDetailViewModel
    @State private var showShare = false

    var body: some View {
        Group {
            if let detail = viewModel.detail {
                content(detail)
            } else if viewModel.notFound {
                ContentUnavailableView("Post unavailable", systemImage: "leaf",
                                       description: Text("This activity is no longer available."))
            } else {
                ProgressView().tint(Eco.textPrimary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.detail != nil {
                EcoInputBar(text: $viewModel.draft, placeholder: "Add a comment…", canSend: viewModel.canSend,
                            isSending: viewModel.isSending) {
                    Task { await viewModel.sendComment() }
                }
            }
        }
        .fullScreenCover(isPresented: $showShare) {
            if let activity = viewModel.detail?.activity {
                ActivityShareLauncher(activity: activity, onClose: { showShare = false })
                    .ecoTheme()
            }
        }
    }

    private func content(_ detail: PostDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Eco.Space.l) {
                    header(detail)

                    Text(detail.title)
                        .font(.ecoDisplaySmall)
                        .foregroundStyle(Eco.textPrimary)

                    EcoStatRow(stats: detail.stats)

                    EcoBanner(
                        systemImage: "leaf.circle.fill",
                        title: detail.bags > 0 ? "≈ \(detail.bags * 45) plastic bottles kept out of waterways" : "Every step counts",
                        subtitle: detail.bags > 0 ? "\(detail.bags) bags collected" : nil
                    )

                    MediaPager(media: detail.media)

                    actions

                    Text(viewModel.boostersText)
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)

                    commentsSection
                }
                .padding(Eco.Space.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.highlightedCommentID) { _, id in
                guard let id else { return }
                withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.clearHighlight()
                }
            }
        }
    }

    private func header(_ detail: PostDetail) -> some View {
        HStack(spacing: Eco.Space.m) {
            EcoAvatar(name: detail.authorName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.isMine ? "You" : detail.authorName)
                    .font(.ecoTitleMedium)
                    .foregroundStyle(Eco.textPrimary)
                Text(detail.dateText)
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        HStack(spacing: Eco.Space.m) {
            Button {
                Task { await viewModel.toggleBoost() }
            } label: {
                EcoLabel(viewModel.boostButtonTitle, systemImage: "hand.thumbsup", size: 18, spacing: 8)
                    .font(.ecoLabelLarge)
                    .foregroundStyle(viewModel.boost.isBoostedByMe ? Eco.primary : Eco.onButton)
                    .padding(.horizontal, Eco.Space.l)
                    .frame(height: 44)
                    .background(viewModel.boost.isBoostedByMe ? Eco.selected : Eco.buttonFill, in: Capsule())
                    .overlay(Capsule().stroke(Eco.primary, lineWidth: viewModel.boost.isBoostedByMe ? 1.5 : 0))
            }
            .buttonStyle(.plain)
            .accessibilityValue("\(viewModel.boost.count)")

            Text("\(viewModel.boost.count)")
                .font(.ecoTitleMedium)
                .monospacedDigit()
                .foregroundStyle(Eco.textSecondary)

            Spacer()

            EcoCircleButton(systemImage: "square.and.arrow.up", label: "Share") { showShare = true }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Eco.Space.m) {
            HStack {
                Text("Comments").font(.ecoHeadlineSmall).foregroundStyle(Eco.textPrimary)
                Spacer()
                Text(viewModel.commentCountText).font(.ecoBodySmall).foregroundStyle(Eco.textSecondary)
            }

            if viewModel.comments.isEmpty {
                Text("No comments yet. Say something nice.")
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ecoCard()
            }

            ForEach(viewModel.comments) { comment in
                CommentRow(
                    comment: comment,
                    timeText: viewModel.timeText(for: comment),
                    isMine: viewModel.isMine(comment),
                    isHighlighted: viewModel.highlightedCommentID == comment.id
                )
                .id(comment.id)
            }

            if let message = viewModel.errorMessage {
                Text(message).font(.ecoBodySmall).foregroundStyle(Eco.error)
            }
        }
    }
}

/// Pager of Before / After photos and the route map; `EcoPhoto` keeps every page inside the column width.
private struct MediaPager: View {
    let media: [PostMedia]
    @State private var page: String?

    var body: some View {
        TabView(selection: Binding(get: { page ?? media.first?.id ?? "" }, set: { page = $0 })) {
            ForEach(media) { item in
                ZStack(alignment: .topLeading) {
                    switch item.content {
                    case .photo(let url):
                        EcoPhoto(image: FakePhotoStore.shared.loadImage(url), height: 260, cornerRadius: Eco.Radius.card)
                    case .route(let coordinates):
                        RouteMapView(coordinates: coordinates.map(\.clLocationCoordinate))
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))
                    }
                    Text(item.title)
                        .font(.ecoLabelMedium)
                        .foregroundStyle(Eco.textPrimary)
                        .padding(.horizontal, Eco.Space.m).padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .padding(Eco.Space.m)
                }
                .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
        .frame(height: 290)
    }
}

private struct CommentRow: View {
    let comment: Comment
    let timeText: String
    let isMine: Bool
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Eco.Space.m) {
            EcoAvatar(name: comment.authorName, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isMine ? "You" : comment.authorName)
                        .font(.ecoTitleSmall)
                        .foregroundStyle(Eco.textPrimary)
                    Text(timeText)
                        .font(.ecoLabelSmall)
                        .foregroundStyle(Eco.textSecondary)
                }
                Text(comment.text)
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Eco.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Eco.selected : Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.field))
            .overlay(
                RoundedRectangle(cornerRadius: Eco.Radius.field)
                    .stroke(Eco.primary, lineWidth: isHighlighted ? 1.5 : 0)
            )
            .animation(.smooth, value: isHighlighted)
        }
    }
}

#Preview {
    NavigationStack { PostDetailView(activityId: SeedIDs.activity(1), highlightCommentID: SeedIDs.comment(1)) }
        .ecoTheme()
}
