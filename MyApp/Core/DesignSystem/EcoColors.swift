import SwiftUI

extension Color {
    /// `Color(hex: 0x5FAD7F)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// EcoPlog palette. Dark green is the primary look of the app, so there is a single
/// (dark) palette and the app forces `.dark` at the root (see `View.ecoTheme()`).
enum Eco {
    // MARK: Brand
    static let primary   = Color(hex: 0x5FAD7F)   // main green
    static let secondary = Color(hex: 0x4A9B6E)   // darker green
    static let accent    = Color(hex: 0x2C5F4F)   // deep green
    static let highlight = Color(hex: 0xB8E6C9)   // light green highlight

    // MARK: Backgrounds
    static let background = Color(hex: 0x1A2522)  // app background (dark green)
    static let surface    = Color(hex: 0x243330)  // cards, bars, sheets
    static let surfaceRaised = Color(hex: 0x2C3D39) // nested elements on a card
    static let border     = Color(hex: 0x35483F)  // subtle green-tinted separators
    static let selected   = primary.opacity(0.18) // selected chip / row

    // MARK: Text
    static let textPrimary   = Color.white
    static let textBody      = Color(hex: 0xE0E8E4)
    static let textSecondary = Color(hex: 0xB0C4BC)
    static let textHint      = Color(hex: 0x6B7F78)
    static let onPrimary     = Color.white

    // MARK: Status
    static let success = primary
    static let error   = Color(hex: 0xD94545)
    static let warning = Color(hex: 0xF59E42)
    static let info    = secondary

    // MARK: Misc
    static let overlay = Color.black.opacity(0.5)

    /// Brand gradient for hero areas, badges and the big Plog button.
    static let brandGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Spacing / radius / elevation tokens.
extension Eco {
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let field: CGFloat = 12
        static let button: CGFloat = 12
        static let card: CGFloat = 16
        static let sheet: CGFloat = 24
    }
}
