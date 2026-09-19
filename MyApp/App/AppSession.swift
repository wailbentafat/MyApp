import Observation
import SwiftUI

/// App-wide session/auth state, owned by P2 (backend + auth). Injected once at
/// the root and read via `Environment` by anything that needs the current user.
@MainActor
@Observable
final class AppSession {
    private(set) var currentUser: User?
    private(set) var isSigningIn = false
    var notificationsEnabled = true

    private let authService: any AuthService

    init(authService: any AuthService = FakeAuthService()) {
        self.authService = authService
    }

    func signInWithApple() async {
        isSigningIn = true
        defer { isSigningIn = false }
        currentUser = try? await authService.signInWithApple()
    }

    func signOut() async {
        await authService.signOut()
        currentUser = nil
    }
}

private struct AppSessionKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = AppSession()
}

extension EnvironmentValues {
    var appSession: AppSession {
        get { self[AppSessionKey.self] }
        set { self[AppSessionKey.self] = newValue }
    }
}
