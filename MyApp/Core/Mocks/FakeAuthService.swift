import Foundation

/// Stands in for Supabase Auth with Sign in with Apple. Produces a stable fake
/// user after a simulated round trip; no `ASAuthorizationController`, no server.
struct FakeAuthService: AuthService {
    func signInWithApple() async throws -> User {
        try await Task.sleep(for: .milliseconds(600))
        return User.demo
    }

    func signOut() async {
        try? await Task.sleep(for: .milliseconds(150))
    }
}
