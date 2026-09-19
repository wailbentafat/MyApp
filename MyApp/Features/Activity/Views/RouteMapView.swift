import MapKit
import SwiftUI

/// Map with the route polyline. Pure presentation: coordinates come from the view model.
struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    var followsLatest = false

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Eco.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let first = coordinates.first, coordinates.count > 1 {
                Annotation("", coordinate: first) { marker(fill: Eco.surface, ring: Eco.primary, size: 12) }
            }
            if let last = coordinates.last {
                Annotation("", coordinate: last) { marker(fill: Eco.primary, ring: .white, size: 16) }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onChange(of: coordinates.count) {
            guard followsLatest, let last = coordinates.last else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                position = .camera(MapCamera(centerCoordinate: last, distance: 500))
            }
        }
    }

    private func marker(fill: Color, ring: Color, size: CGFloat) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(ring, lineWidth: 3))
    }
}
