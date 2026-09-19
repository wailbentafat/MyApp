import SwiftUI

/// Full-screen container for the Activity flow. It only switches screens; all logic is in `ActivityViewModel`.
struct ActivityFlowView: View {
    @Bindable var viewModel: ActivityViewModel
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            switch viewModel.screen {
            case .setup:
                RecordSetupView(viewModel: viewModel, onClose: onClose)
                    .transition(.opacity)
            case .recording:
                RecordingView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            case .impactLog:
                ImpactLogView(viewModel: viewModel, onDiscard: onClose)
                    .transition(.move(edge: .trailing))
            case .summary:
                ActivitySummaryView(viewModel: viewModel, onDone: onClose)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.screen)
        .interactiveDismissDisabled(viewModel.screen != .setup)
    }
}
