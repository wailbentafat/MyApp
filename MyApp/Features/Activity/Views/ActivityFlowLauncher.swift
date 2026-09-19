import SwiftUI

/// Entry point other features use to start an activity:
/// `.fullScreenCover(isPresented:) { ActivityFlowLauncher(cleanUp: cleanUp, onFinished: ...) }`.
/// Builds the view model from the environment (repositories + current user), and hands the finished
/// `Activity` back through `onFinished`, so the caller can upload it, close the Clean-Up and publish to the feed.
struct ActivityFlowLauncher: View {
    let cleanUp: CleanUp?
    var onFinished: (Activity) -> Void

    @Environment(\.activityRepository) private var activityRepository
    @Environment(\.appSession) private var appSession
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityViewModel?

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                ActivityFlowView(viewModel: viewModel) {
                    if let activity = viewModel.savedActivity { onFinished(activity) }
                    dismiss()
                }
            }
        }
        .task {
            guard viewModel == nil, let user = appSession.currentUser else { return }
            viewModel = AppEnvironment.makeActivityViewModel(
                context: cleanUp.map(ActivityContext.cleanUp) ?? .free,
                userId: user.id,
                activities: activityRepository
            )
        }
    }
}
