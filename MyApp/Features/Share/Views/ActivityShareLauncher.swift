import SwiftUI

/// Entry point: shows the share preview for an activity.
/// - After finishing an activity: `showsDone: true` (Done button closes the flow).
/// - From Profile: a plain preview that can be shared again any time.
struct ActivityShareLauncher: View {
    let activity: Activity
    var showsDone = false
    var onClose: () -> Void

    @Environment(\.shareService) private var shareService
    @State private var viewModel: ActivityShareViewModel?

    var body: some View {
        ZStack {
            Eco.background.ignoresSafeArea()
            if let viewModel {
                ActivityShareView(viewModel: viewModel, onClose: onClose)
            }
        }
        .task {
            guard viewModel == nil else { return }
            let model = ActivityShareViewModel(
                activity: activity, showsDone: showsDone,
                snapshotter: LiveMapSnapshotter(), renderer: LiveStoryRenderer(),
                exporter: LiveImageExporter(), share: shareService
            )
            viewModel = model
            await model.prepare()
        }
    }
}
