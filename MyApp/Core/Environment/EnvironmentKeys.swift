import SwiftUI

/// Dependency injection via `Environment`, per the plan's architecture rules.
/// Every key defaults to the fake implementation so previews and any view that
/// forgets to inject explicitly still work.

private struct CleanUpRepositoryKey: EnvironmentKey {
    static let defaultValue: any CleanUpRepository = FakeBackendService()
}

private struct ActivityRepositoryKey: EnvironmentKey {
    static let defaultValue: any ActivityRepository = FakeBackendService()
}

private struct FeedServiceKey: EnvironmentKey {
    static let defaultValue: any FeedService = FakeBackendService()
}

private struct ScannerServiceKey: EnvironmentKey {
    static let defaultValue: any ScannerService = FakeScannerService()
}

private struct NotificationServiceKey: EnvironmentKey {
    static let defaultValue: any NotificationService = FakeNotificationService()
}

private struct ShareServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ShareService = FakeShareService()
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: any AuthService = FakeAuthService()
}

extension EnvironmentValues {
    var cleanUpRepository: any CleanUpRepository {
        get { self[CleanUpRepositoryKey.self] }
        set { self[CleanUpRepositoryKey.self] = newValue }
    }

    var activityRepository: any ActivityRepository {
        get { self[ActivityRepositoryKey.self] }
        set { self[ActivityRepositoryKey.self] = newValue }
    }

    var feedService: any FeedService {
        get { self[FeedServiceKey.self] }
        set { self[FeedServiceKey.self] = newValue }
    }

    var scannerService: any ScannerService {
        get { self[ScannerServiceKey.self] }
        set { self[ScannerServiceKey.self] = newValue }
    }

    var notificationService: any NotificationService {
        get { self[NotificationServiceKey.self] }
        set { self[NotificationServiceKey.self] = newValue }
    }

    @MainActor
    var shareService: any ShareService {
        get { self[ShareServiceKey.self] }
        set { self[ShareServiceKey.self] = newValue }
    }

    var authService: any AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}
