import UIKit

struct ShareStat: Identifiable, Hashable {
    let label: String
    let value: String
    var id: String { label }
}

/// Everything one 9:16 story card needs to draw itself (plain data, no logic).
struct ShareCardModel: Identifiable {
    enum Kind: String { case route, photo, beforeAfter, impact }

    let id = UUID()
    let kind: Kind
    let title: String
    let dateText: String
    let stats: [ShareStat]

    /// Route card: map background (optional) and the route as points normalized to 0...1 of the card.
    var mapImage: UIImage?
    var routePoints: [CGPoint] = []

    /// Photo / Before-After cards.
    var photo: UIImage?
    var beforePhoto: UIImage?
    var afterPhoto: UIImage?

    /// Impact card.
    var bottlesText: String = ""
    var wasteChips: [String] = []

    var accessibilityName: String {
        switch kind {
        case .route: "Route map"
        case .photo: "Photo"
        case .beforeAfter: "Before and After"
        case .impact: "Impact"
        }
    }
}

/// Fixed story canvas: 360×640 points, rendered at 3× = 1080×1920 (Instagram Stories size).
enum StoryCanvas {
    static let size = CGSize(width: 360, height: 640)
    static let renderScale: CGFloat = 3
}
