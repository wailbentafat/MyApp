import CoreLocation
import Observation

/// One-shot location + heading fix used by Spot (to geotag the Before photo) and
/// the Map's "near me" button. Real `CoreLocation` — not part of what we're faking.
@MainActor
@Observable
final class LocationFixProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var headingDegrees: Double?

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Resolves once with the best available fix, or `nil` if permission is denied
    /// or no fix arrives within a few seconds.
    func requestFix() async -> (coordinate: Coordinate, heading: Double)? {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return nil
        }

        manager.startUpdatingHeading()
        let location = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            locationContinuation = continuation
            manager.requestLocation()
        }
        manager.stopUpdatingHeading()

        guard let location else { return nil }
        let heading = headingDegrees ?? 0
        return (Coordinate(location.coordinate), heading)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last
        Task { @MainActor in
            locationContinuation?.resume(returning: lastLocation)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            headingDegrees = degrees
        }
    }
}
