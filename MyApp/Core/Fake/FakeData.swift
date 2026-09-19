import CoreLocation
import Foundation

/// Fake data used while the real backend, sensors and Person 2's features are not plugged in.
enum FakeData {
    static let cleanUps: [CleanUp] = [
        CleanUp(
            title: "Jardin d'Essai riverside",
            latitude: 36.7472, longitude: 3.0765,
            status: .scheduled,
            wasteTypes: [.plastic, .glass],
            gear: ["Heavy-duty gloves", "Trash picker", "3× 50 L bags"],
            estimatedBags: 3
        ),
        CleanUp(
            title: "Beach path near the pier",
            latitude: 36.7610, longitude: 3.0500,
            status: .open,
            wasteTypes: [.plastic, .bulky],
            gear: ["Gloves", "Trash picker", "5× 50 L bags"],
            estimatedBags: 5
        ),
    ]

    static var activities: [Activity] { [] }

    /// A ~500 m loop the fake GPS walks around.
    static let walkCircuit = Circuit(
        origin: CLLocationCoordinate2D(latitude: 36.7472, longitude: 3.0765),
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
            let index = (cumulative.lastIndex { $0 <= d } ?? 0).clamped(to: 0...(points.count - 2))
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

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}
