import CoreLocation
import Foundation

/// Fake data for the simulated GPS. (Clean-Ups, feed posts and users live in `Fixtures`, owned by Person 2.)
enum FakeData {
    /// A ~500 m loop the fake GPS walks around, near the seeded Clean-Ups.
    static let walkCircuit = Circuit(
        origin: CLLocationCoordinate2D(
            latitude: Fixtures.homeCoordinate.latitude,
            longitude: Fixtures.homeCoordinate.longitude
        ),
        offsets: [(0, 0), (0.0012, 0), (0.0014, 0.0010), (0.0006, 0.0016), (-0.0002, 0.0011), (0, 0)]
    )

    struct Circuit: Sendable {
        let points: [CLLocation]
        let cumulative: [Double]
        var length: Double { cumulative.last ?? 0 }

        init(origin: CLLocationCoordinate2D, offsets: [(lat: Double, lon: Double)]) {
            points = offsets.map {
                CLLocation(latitude: origin.latitude + $0.lat, longitude: origin.longitude + $0.lon)
            }
            var total = 0.0
            var sums = [0.0]
            for index in 1..<points.count {
                total += points[index].distance(from: points[index - 1])
                sums.append(total)
            }
            cumulative = sums
        }

        /// The point `distance` metres along the loop (wraps around).
        func location(atDistance distance: Double, speed: Double) -> CLLocation {
            let d = distance.truncatingRemainder(dividingBy: max(length, 1))
            let last = points.count - 2
            let index = min(max(cumulative.lastIndex { $0 <= d } ?? 0, 0), last)
            let segment = max(cumulative[index + 1] - cumulative[index], 0.001)
            let t = (d - cumulative[index]) / segment
            let a = points[index].coordinate, b = points[index + 1].coordinate
            let coordinate = CLLocationCoordinate2D(
                latitude: a.latitude + (b.latitude - a.latitude) * t,
                longitude: a.longitude + (b.longitude - a.longitude) * t
            )
            let altitude = 30 + 6 * sin(distance / 60)
            return CLLocation(
                coordinate: coordinate, altitude: altitude,
                horizontalAccuracy: 5, verticalAccuracy: 5,
                course: -1, speed: speed, timestamp: .now
            )
        }
    }
}
