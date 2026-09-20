import MapKit
import Photos
import SwiftUI
import UIKit

// MARK: - Map snapshot

struct MapSnapshotResult {
    let image: UIImage
    /// The route projected into the snapshot, normalized to 0...1 of the image.
    let normalizedPoints: [CGPoint]
}

/// Renders a map picture for a route. Live uses MKMapSnapshotter; when it fails (offline) the view model
/// falls back to a plain background and projects the route itself.
@MainActor
protocol MapSnapshotting: AnyObject {
    func snapshot(route: [Coordinate], size: CGSize) async -> MapSnapshotResult?
}

@MainActor
final class LiveMapSnapshotter: MapSnapshotting {
    func snapshot(route: [Coordinate], size: CGSize) async -> MapSnapshotResult? {
        guard route.count > 1 else { return nil }
        let points = route.map { MKMapPoint($0.clLocationCoordinate) }
        var rect = points.dropFirst().reduce(MKMapRect(origin: points[0], size: MKMapSize(width: 0, height: 0))) {
            $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
        }
        // Pad, match the card aspect ratio, and shift the route into the upper part (stats sit at the bottom).
        let aspect = size.width / size.height
        var width = max(rect.width * 1.6, 600)
        var height = max(rect.height * 1.6, 600)
        if width / height > aspect { height = width / aspect } else { width = height * aspect }
        rect = MKMapRect(x: rect.midX - width / 2, y: rect.midY - height / 2 + height * 0.14, width: width, height: height)

        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.scale = 2
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let normalized = route.map { coordinate -> CGPoint in
            let point = snapshot.point(for: coordinate.clLocationCoordinate)
            return CGPoint(x: point.x / size.width, y: point.y / size.height)
        }
        return MapSnapshotResult(image: snapshot.image, normalizedPoints: normalized)
    }
}

// MARK: - Story image rendering

@MainActor
protocol StoryImageRendering: AnyObject {
    func render(_ card: ShareCardModel) -> UIImage?
}

@MainActor
final class LiveStoryRenderer: StoryImageRendering {
    func render(_ card: ShareCardModel) -> UIImage? {
        let content = StoryCardView(model: card)
            .frame(width: StoryCanvas.size.width, height: StoryCanvas.size.height)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = StoryCanvas.renderScale
        return renderer.uiImage
    }
}

// MARK: - Exporting (Photos / pasteboard)

@MainActor
protocol ImageExporting: AnyObject {
    func saveToPhotos(_ image: UIImage) async -> Bool
    func copy(_ image: UIImage)
}

@MainActor
final class LiveImageExporter: ImageExporting {
    func saveToPhotos(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func copy(_ image: UIImage) {
        UIPasteboard.general.image = image
    }
}
