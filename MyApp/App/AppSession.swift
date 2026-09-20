import Observation
import SwiftUI

/// App-wide session/auth state, owned by P2 (backend + auth). Injected once at
/// the root and read via `Environment` by anything that needs the current user.
@MainActor
@Observable
final class AppSession {
    private(set) var currentUser: User?
    private(set) var isSigningIn = false
    private(set) var notificationsEnabled: Bool

    private let authService: any AuthService
    private let defaults: UserDefaults

    private enum Key {
        static let user = "heal.session.user"
        static let notifications = "heal.settings.notificationsEnabled"
    }

    /// Restores the signed-in user and settings from `defaults`, so the app doesn't show Welcome on every launch.
    init(authService: any AuthService = FakeAuthService(), defaults: UserDefaults = .standard) {
        self.authService = authService
        self.defaults = defaults
        self.notificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? true
        if let data = defaults.data(forKey: Key.user) {
            self.currentUser = try? JSONDecoder().decode(User.self, from: data)
        }
    }

    func signInWithApple() async {
        isSigningIn = true
        defer { isSigningIn = false }
        currentUser = try? await authService.signInWithApple()
        defaults.set(currentUser.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.user)
    }

    func signOut() async {
        await authService.signOut()
        currentUser = nil
        defaults.removeObject(forKey: Key.user)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: Key.notifications)
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
