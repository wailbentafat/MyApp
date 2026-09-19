import CoreLocation

/// Thin wrapper over the GPS. No business rules here: filtering, distance and pace live in `ActivityViewModel`.
@MainActor
protocol LocationProviding: AnyObject {
    func requestAuthorization()
    /// Starts updates; the stream ends when `stopUpdates()` is called or the consumer stops iterating.
    func startUpdates() -> AsyncStream<CLLocation>
    func stopUpdates()
}

// MARK: - Live

@MainActor
final class LiveLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.manager.allowsBackgroundLocationUpdates = true
            self.manager.showsBackgroundLocationIndicator = true
            self.manager.startUpdatingLocation()
            continuation.onTermination = { _ in
                Task { @MainActor in self.manager.stopUpdatingLocation() }
            }
        }
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        continuation?.finish()
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations { self.continuation?.yield(location) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Fake (simulated walk around a small loop)

@MainActor
final class FakeLocationProvider: LocationProviding {
    private let speed: Double
    private var task: Task<Void, Never>?

    /// - Parameter speed: metres per second of the simulated walker (2.5 ≈ brisk walk, good for demos).
    init(speed: Double = 2.5) { self.speed = speed }

    func requestAuthorization() {}

    func startUpdates() -> AsyncStream<CLLocation> {
        let circuit = FakeData.walkCircuit
        let speed = speed
        return AsyncStream { continuation in
            let task = Task {
                var travelled = 0.0
                while !Task.isCancelled {
                    continuation.yield(circuit.location(atDistance: travelled, speed: speed))
                    travelled += speed
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }
            self.task = task
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stopUpdates() {
        task?.cancel()
        task = nil
    }
}
