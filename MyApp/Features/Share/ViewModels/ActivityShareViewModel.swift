import Observation
import UIKit

/// Pure route → card projection (fake fallback when no map snapshot is available).
enum RouteProjector {
    /// Fits the route into `rect` (normalized 0...1 card space), keeping its aspect ratio, north up.
    static func normalize(_ route: [Coordinate], in rect: CGRect) -> [CGPoint] {
        guard route.count > 1 else { return [] }
        let lats = route.map(\.latitude), lons = route.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!, minLon = lons.min()!, maxLon = lons.max()!
        let meanLat = (minLat + maxLat) / 2
        let lonScale = cos(meanLat * .pi / 180)
        let width = max((maxLon - minLon) * lonScale, 1e-9)
        let height = max(maxLat - minLat, 1e-9)
        let scale = min(rect.width / width, rect.height / height)
        let offsetX = rect.minX + (rect.width - width * scale) / 2
        let offsetY = rect.minY + (rect.height - height * scale) / 2
        return route.map { coordinate in
            CGPoint(
                x: offsetX + (coordinate.longitude - minLon) * lonScale * scale,
                y: offsetY + (maxLat - coordinate.latitude) * scale
            )
        }
    }

    /// Keeps at most `limit` points so rendering stays cheap.
    static func simplify(_ points: [CGPoint], limit: Int = 240) -> [CGPoint] {
        guard points.count > limit, limit > 1 else { return points }
        let step = Double(points.count - 1) / Double(limit - 1)
        return (0..<limit).map { points[Int((Double($0) * step).rounded())] }
    }
}

/// Share preview for one activity: builds the story cards (route / photo / Before-After / impact),
/// renders the selected card to a 1080×1920 image, and shares it (Instagram Story, Photos, clipboard, more).
@Observable @MainActor
final class ActivityShareViewModel {
    let activity: Activity
    let showsDone: Bool
    private(set) var cards: [ShareCardModel] = []
    private(set) var isPreparing = true
    private(set) var isSharing = false
    private(set) var toast: String?
    var currentIndex = 0

    @ObservationIgnored private let snapshotter: MapSnapshotting
    @ObservationIgnored private let renderer: StoryImageRendering
    @ObservationIgnored private let exporter: ImageExporting
    @ObservationIgnored private let share: ShareService
    @ObservationIgnored private var imageCache: [UUID: UIImage] = [:]
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(activity: Activity, showsDone: Bool = false, snapshotter: MapSnapshotting, renderer: StoryImageRendering,
         exporter: ImageExporting, share: ShareService) {
        self.activity = activity
        self.showsDone = showsDone
        self.snapshotter = snapshotter
        self.renderer = renderer
        self.exporter = exporter
        self.share = share
    }

    // MARK: Cards

    var currentCard: ShareCardModel? { cards.indices.contains(currentIndex) ? cards[currentIndex] : nil }
    var caption: String { "\(activity.title): \(distanceText), \(activity.impactLog.bags) bags collected with \(AppInfo.name) 🌱" }

    func prepare() async {
        var built: [ShareCardModel] = []
        let coordinates = activity.route.map(\.coordinate)

        if coordinates.count > 1 {
            var route = makeCard(.route, stats: [
                ShareStat(label: "Distance", value: distanceText), ShareStat(label: "Time", value: timeText),
                ShareStat(label: "Pace", value: paceText), ShareStat(label: "Bags", value: "\(activity.impactLog.bags)"),
            ])
            if let snapshot = await snapshotter.snapshot(route: coordinates, size: StoryCanvas.size) {
                route.mapImage = snapshot.image
                route.routePoints = RouteProjector.simplify(snapshot.normalizedPoints)
            } else {
                route.routePoints = RouteProjector.simplify(
                    RouteProjector.normalize(coordinates, in: CGRect(x: 0.14, y: 0.13, width: 0.72, height: 0.42))
                )
            }
            built.append(route)
        }

        var photoCard = makeCard(.photo, stats: [
            ShareStat(label: "Distance", value: distanceText), ShareStat(label: "Time", value: timeText),
            ShareStat(label: "Bags", value: "\(activity.impactLog.bags)"),
        ])
        photoCard.photo = FakePhotoStore.shared.loadImage(activity.afterPhotoURL ?? fallbackPhotoURL)
        built.append(photoCard)

        let beforeURL = activity.beforePhotoURL
        let afterURL = activity.afterPhotoURL ?? DemoPhotos.pairedAfter(for: beforeURL)
        if let before = FakePhotoStore.shared.loadImage(beforeURL), let after = FakePhotoStore.shared.loadImage(afterURL) {
            var beforeAfter = makeCard(.beforeAfter, stats: [
                ShareStat(label: "Distance", value: distanceText), ShareStat(label: "Bags", value: "\(activity.impactLog.bags)"),
                ShareStat(label: "Time", value: timeText),
            ])
            beforeAfter.beforePhoto = before
            beforeAfter.afterPhoto = after
            built.append(beforeAfter)
        }

        var impact = makeCard(.impact, stats: [
            ShareStat(label: "Bags", value: "\(activity.impactLog.bags)"),
            ShareStat(label: "Weight", value: String(format: "%.1f kg", activity.impactLog.kg)),
            ShareStat(label: "Items", value: "\(activity.impactLog.totalItems)"),
        ])
        impact.bottlesText = "≈ \(activity.impactLog.bags * 45) plastic bottles kept out of waterways"
        impact.wasteChips = WasteType.allCases
            .filter { activity.impactLog.count(for: $0) > 0 }
            .map { "\($0.label) \(activity.impactLog.count(for: $0))" }
        built.append(impact)

        cards = built
        currentIndex = 0
        isPreparing = false
    }

    // MARK: Sharing

    /// The rendered 1080×1920 image of the selected card (cached per card).
    func currentImage() -> UIImage? {
        guard let card = currentCard else { return nil }
        if let cached = imageCache[card.id] { return cached }
        guard let image = renderer.render(card) else { return nil }
        imageCache[card.id] = image
        return image
    }

    func shareToInstagramStory() async {
        guard !isSharing, let image = currentImage() else { return }
        isSharing = true
        defer { isSharing = false }
        switch await share.shareToInstagramStory(image: image, videoURL: nil, caption: caption) {
        case .postedToInstagram: showToast("Opened Instagram Stories")
        case .openedShareSheet: showToast("Shared")
        case .cancelled: break
        }
    }

    func saveToPhotos() async {
        guard let image = currentImage() else { return }
        showToast(await exporter.saveToPhotos(image) ? "Saved to Photos" : "Couldn't save. Check Photos access.")
    }

    func copyImage() {
        guard let image = currentImage() else { return }
        exporter.copy(image)
        showToast("Copied")
    }

    // MARK: Text

    var distanceText: String { String(format: "%.2f km", activity.distance / 1000) }
    var timeText: String { ActivityViewModel.formatDuration(activity.duration) }
    var paceText: String {
        ActivityViewModel.formatPace(speed: activity.duration > 0 ? activity.distance / activity.duration : 0) + " /km"
    }
    var dateText: String { activity.startedAt.formatted(date: .abbreviated, time: .shortened) }

    // MARK: Private

    private func makeCard(_ kind: ShareCardModel.Kind, stats: [ShareStat]) -> ShareCardModel {
        ShareCardModel(kind: kind, title: activity.title, dateText: dateText, stats: stats)
    }

    /// Fake-data fallback so the photo card is never empty: a volunteer photo picked from the activity id.
    private var fallbackPhotoURL: URL? {
        let names = DemoPhotos.crewNames
        return DemoPhotos.url(names[Int(activity.id.uuid.0) % names.count])
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}
