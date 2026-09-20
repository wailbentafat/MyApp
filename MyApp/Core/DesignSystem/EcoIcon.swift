import SwiftUI

/// hɛal icon system. Every icon in the UI goes through `EcoSymbol`, which draws a bundled vector icon
/// (`Assets.xcassets/Icons/ic-<name>`) and falls back to the SF Symbol only if there is no mapping.
///
/// The bundled icons are Lucide (ISC) stand-ins for the Figma iconography, which we could not read.
/// To use the Figma icons: export each as SVG and overwrite the matching `ic-<name>.svg` (same file name),
/// nothing else changes.
enum EcoIcon {
    /// Asset name for an SF Symbol name, if we have a bundled replacement.
    static func asset(for systemName: String) -> String? {
        guard let name = table[systemName] else { return nil }
        return "ic-" + name
    }

    // SF Symbol → bundled icon name (see the `Icons` asset folder).
    private static let table: [String: String] = [
        // navigation
        "house.fill": "house", "house": "house",
        "map.fill": "map", "map": "map",
        "plus.circle.fill": "circle-plus", "plus": "plus", "minus": "minus",
        "calendar": "calendar-days",
        "person.fill": "user", "person.2.fill": "users", "person.crop.circle.fill": "user-round",
        "bell": "bell", "xmark": "x", "info": "info", "sparkles": "sparkles",
        "rectangle.portrait.and.arrow.right": "log-out",
        // capture & media
        "camera.fill": "camera", "camera.viewfinder": "scan-line",
        "photo": "image", "photo.fill": "image", "photo.on.rectangle": "image",
        // activity
        "figure.walk": "person-standing", "figure.walk.circle": "person-standing",
        "figure.walk.circle.fill": "person-standing", "figure.run": "person-standing",
        "figure.run.circle": "person-standing", "figure.run.circle.fill": "person-standing",
        "flame.fill": "flame", "timer": "timer", "activity": "activity",
        "gauge.with.dots.needle.67percent": "gauge", "speedometer": "gauge",
        "mountain.2.fill": "mountain", "shoeprints.fill": "footprints", "heart.fill": "heart-pulse",
        "play.fill": "play", "play.circle.fill": "play", "pause.fill": "pause",
        // places
        "mappin.circle.fill": "map-pin", "mappin.and.ellipse": "map-pin", "location.fill": "locate-fixed",
        // social
        "hand.thumbsup": "thumbs-up", "hand.thumbsup.fill": "thumbs-up",
        "square.and.arrow.up": "share", "checkmark.seal.fill": "badge-check",
        "checkmark.circle.fill": "circle-check", "circle": "circle",
        // environment & waste
        "leaf.fill": "leaf", "leaf": "leaf", "leaf.circle.fill": "leaf",
        "bag.fill": "shopping-bag", "bag": "shopping-bag",
        "trash.fill": "trash-2", "trash.circle.fill": "trash-2",
        "waterbottle": "cup-soda", "wineglass.fill": "wine", "sofa.fill": "armchair",
        "smoke.fill": "cigarette", "newspaper.fill": "file-text",
        "exclamationmark.triangle.fill": "triangle-alert", "questionmark.circle.fill": "circle-help",
        "wrench.and.screwdriver": "wrench",
        // sharing, notifications, camera
        "instagram.logo": "instagram", "square.and.arrow.down": "download", "doc.on.doc": "copy",
        "ellipsis": "ellipsis", "heart": "heart", "bubble.left.fill": "message-circle",
        "paperplane.fill": "send", "bolt.fill": "zap", "bolt.slash.fill": "zap-off", "chevron.right": "chevron-right",
    ]
}

/// Drop-in replacement for `Image(systemName:)` that uses the bundled icon set.
struct EcoSymbol: View {
    let name: String
    var size: CGFloat

    init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    var body: some View {
        if let asset = EcoIcon.asset(for: name) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.9))
                .frame(width: size, height: size)
        }
    }
}

/// Icon + text on one line (replacement for `Label(_, systemImage:)`).
struct EcoLabel: View {
    let title: String
    let systemImage: String
    var size: CGFloat = 16
    var spacing: CGFloat = 6

    init(_ title: String, systemImage: String, size: CGFloat = 16, spacing: CGFloat = 6) {
        self.title = title
        self.systemImage = systemImage
        self.size = size
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            EcoSymbol(systemImage, size: size)
            Text(title)
        }
    }
}
