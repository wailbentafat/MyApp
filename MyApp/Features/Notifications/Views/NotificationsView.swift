import SwiftUI

/// Notifications inbox: likes on activities, comments, community reactions.
struct NotificationsView: View {
    var onClose: () -> Void

    @Environment(\.inboxService) private var inbox
    @State private var viewModel: NotificationsViewModel?
    @State private var path: [NotificationsViewModel.NotificationDestination] = []

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                NavigationStack(path: $path) {
                    Content(viewModel: viewModel, onClose: onClose) { destination in
                        path.append(destination)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: NotificationsViewModel.NotificationDestination.self) { destination in
                        switch destination {
                        case .post(let activityId, let highlight):
                            PostDetailView(activityId: activityId, highlightCommentID: highlight)
                        case .cleanUp(let id):
                            CleanUpDetailRoute(cleanUpId: id, selectedTab: .constant(.home))
                        }
                    }
                }
            }
        }
        .task {
            guard viewModel == nil else { return }
            let model = NotificationsViewModel(inbox: inbox)
            viewModel = model
            await model.load()
            await model.subscribe()
        }
    }
}

private struct Content: View {
    @Bindable var viewModel: NotificationsViewModel
    var onClose: () -> Void
    var onOpen: (NotificationsViewModel.NotificationDestination) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EcoTopBar(title: "Notifications") {
                EcoCircleButton(systemImage: "xmark", label: "Close", action: onClose)
            } trailing: {
                Button("Read all") { Task { await viewModel.markAllRead() } }
                    .font(.ecoLabelLarge)
                    .foregroundStyle(viewModel.hasUnread ? Eco.buttonFill : Eco.textHint)
                    .padding(.horizontal, Eco.Space.l)
                    .frame(height: 44)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .disabled(!viewModel.hasUnread)
            }

            EcoSegmentedTabs(
                items: NotificationsViewModel.Filter.allCases.map { EcoSegmentItem(tab: $0, title: $0.title) },
                selection: $viewModel.filter
            )
            .padding(.horizontal, Eco.Space.l)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Eco.Space.l, pinnedViews: []) {
                    if viewModel.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("Nothing new", systemImage: "bell",
                                               description: Text(viewModel.emptyMessage))
                            .padding(.top, Eco.Space.xxl)
                    }
                    ForEach(viewModel.sections) { section in
                        VStack(alignment: .leading, spacing: Eco.Space.s) {
                            Text(section.title)
                                .font(.ecoHeadlineSmall)
                                .foregroundStyle(Eco.textPrimary)
                            VStack(spacing: 0) {
                                ForEach(section.items) { item in
                                    NotificationRow(viewModel: viewModel, item: item, onOpen: onOpen)
                                    if item.id != section.items.last?.id {
                                        Divider().overlay(Eco.border)
                                    }
                                }
                            }
                            .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
                        }
                    }
                }
                .padding(Eco.Space.l)
            }
        }
    }
}

private struct NotificationRow: View {
    let viewModel: NotificationsViewModel
    let item: AppNotification
    var onOpen: (NotificationsViewModel.NotificationDestination) -> Void

    var body: some View {
        Button {
            Task { onOpen(await viewModel.open(item)) }
        } label: {
            HStack(alignment: .top, spacing: Eco.Space.m) {
                avatar

                VStack(alignment: .leading, spacing: Eco.Space.s) {
                    (Text(viewModel.actorText(for: item)).font(.ecoTitleMedium).foregroundStyle(Eco.textPrimary)
                     + Text(viewModel.actionText(for: item)).font(.ecoBodyMedium).foregroundStyle(Eco.textBody))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let comment = item.commentText {
                        Text(comment)
                            .font(.ecoBodySmall)
                            .foregroundStyle(Eco.textBody)
                            .padding(Eco.Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Eco.surfaceRaised, in: RoundedRectangle(cornerRadius: Eco.Radius.field))
                    }

                    Text(viewModel.timeText(for: item))
                        .font(.ecoLabelSmall)
                        .foregroundStyle(Eco.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(spacing: Eco.Space.s) {
                    if let image = FakePhotoStore.shared.loadImage(item.photoURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if !item.isRead {
                        Circle().fill(Eco.primary).frame(width: 9, height: 9)
                            .accessibilityLabel("Unread")
                    }
                }
            }
            .padding(Eco.Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        EcoAvatar(name: item.actorName, size: 44)
            .overlay(alignment: .bottomTrailing) {
                EcoSymbol(viewModel.iconName(for: item.kind), size: 11)
                    .foregroundStyle(Eco.onButton)
                    .frame(width: 20, height: 20)
                    .background(Eco.buttonFill, in: Circle())
                    .overlay(Circle().stroke(Eco.surface, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
    }
}

#Preview {
    NotificationsView(onClose: {})
        .ecoTheme()
}
