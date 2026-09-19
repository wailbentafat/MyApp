import Foundation

/// One-shot location + heading fix. `LocationFixProvider` is the live implementation; tests use a stub.
@MainActor
protocol LocationFixing: AnyObject {
    func requestWhenInUseAuthorization()
    func requestFix() async -> (coordinate: Coordinate, heading: Double)?
}

extension LocationFixProvider: LocationFixing {}
