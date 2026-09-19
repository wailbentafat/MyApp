import SwiftUI

/// Decides Welcome vs. the tabbed app based on the (fake) session.
struct RootView: View {
    @Environment(\.appSession) private var appSession

    var body: some View {
        Group {
            if appSession.currentUser != nil {
                RootTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut, value: appSession.currentUser)
    }
}

#Preview {
    RootView()
        .ecoTheme()
}
