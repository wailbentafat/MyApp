import SwiftUI

/// Clean-Ups tab (Strava "Groups → Events"): Upcoming / Near you / Done.
struct CleanUpsView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.appSession) private var appSession

    @State private var viewModel: CleanUpsViewModel?
    @State private var openedCleanUp: CleanUp?

    var body: some View {
        VStack(spacing: 0) {
            EcoTopBar(title: "Clean-Ups") {
                EmptyView()
            } trailing: {
                EmptyView()
            }

            if let viewModel {
                EcoSegmentedTabs(
                    items: CleanUpsViewModel.Segment.allCases.map { EcoSegmentItem(tab: $0, title: $0.title) },
                    selection: Binding(get: { viewModel.segment }, set: { viewModel.segment = $0 })
                )
                .padding(.horizontal, Eco.Space.l)

                if viewModel.showsCalendar {
                    EcoCalendarStrip(days: viewModel.calendarDays, selected: viewModel.selectedDay) {
                        viewModel.selectDay($0)
                    }
                    .padding(.top, Eco.Space.m)
                }

                ScrollView {
                    LazyVStack(spacing: Eco.Space.m) {
                        if viewModel.items.isEmpty {
                            ContentUnavailableView("Nothing here yet", systemImage: "leaf",
                                                   description: Text(viewModel.emptyMessage))
                        }
                        ForEach(viewModel.items) { cleanUp in
                            CleanUpCard(
                                cleanUp: cleanUp,
                                subtitle: viewModel.subtitle(for: cleanUp),
                                rsvpTitle: viewModel.rsvpTitle(for: cleanUp),
                                isGoing: viewModel.isAttending(cleanUp),
                                onOpen: { openedCleanUp = cleanUp },
                                onRSVP: { Task { await viewModel.toggleRSVP(cleanUp) } }
                            )
                        }
                    }
                    .padding(Eco.Space.l)
                }
            } else {
                Spacer()
            }
        }
        .ecoScreenBackground()
        .task {
            guard viewModel == nil, let user = appSession.currentUser else { return }
            let model = CleanUpsViewModel(userId: user.id, repository: cleanUpRepository)
            viewModel = model
            await model.load()
            await model.subscribe()
        }
        .sheet(item: $openedCleanUp) { cleanUp in
            NavigationStack { CleanUpDetailView(cleanUp: cleanUp, selectedTab: $selectedTab) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
