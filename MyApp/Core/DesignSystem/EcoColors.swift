import SwiftUI
import UIKit

// MARK: - Helpers

extension Color {
    /// `Color(hex: 0x63C78B)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Color that follows the light/dark appearance: `Color(light: 0xF8F8F8, dark: 0x0A0F1D)`.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Foundations palette (Figma "Confy" → Foundations / Colors)

/// Raw scales exactly as in the Figma foundations, each with a light and a dark value.
/// Features should use the semantic `Eco.*` tokens below, not these directly.
enum EcoPalette {
    struct Scale {
        let s50, s100, s200, s300, s400, s500, s600, s700: Color

        init(light: [UInt32], dark: [UInt32]) {
            precondition(light.count == 8 && dark.count == 8)
            let c = (0..<8).map { Color(light: light[$0], dark: dark[$0]) }
            s50 = c[0]
            s100 = c[1]
            s200 = c[2]
            s300 = c[3]
            s400 = c[4]
            s500 = c[5]
            s600 = c[6]
            s700 = c[7]
        }
    }

    // Main
    static let white = Color(hex: 0xFFFFFF)
    static let darkBlue = Color(hex: 0x0A0F1D)
    static let black = Color(hex: 0x030712)

    // Brand (greens)
    static let brand = Scale(
        light: [0xF1FBF5, 0xF1FBF5, 0xB8EDD0, 0x8DE1B2, 0x63C78B, 0x4FB876, 0x3C9F63, 0x2E7F4E],
        dark:  [0x0F261B, 0x143323, 0x1B4430, 0x245A3E, 0x2E7F4E, 0x63C78B, 0x7ED6A1, 0x9FE5B9]
    )

    // Grey: steps 0,100,200,300,400,500,600,900 (mapped onto s50…s700 slots in that order)
    static let grey = Scale(
        light: [0xF8F8F8, 0xF1F1F1, 0xE1E1E1, 0xC7C7C7, 0x72707A, 0x6F6F6F, 0x39383D, 0x111217],
        dark:  [0x0A0F1D, 0x2B4232, 0x1A2921, 0x212332, 0x6F6F6F, 0x9E9E9E, 0xE1E1E1, 0xFFFFFF]
    )

    // Semantics
    static let success = Scale(
        light: [0xF0FDF4, 0xDCFCE7, 0xBBF7D0, 0x86EFAC, 0x4ADE80, 0x16A34A, 0x15803D, 0x166534],
        dark:  [0x0F2A1C, 0x133524, 0x18432E, 0x1F5A3C, 0x2F8F5E, 0x4ADE80, 0x6EE7A8, 0x86EFAC]
    )
    static let info = Scale(
        light: [0xF2F7FF, 0xE0ECFF, 0xB8D3FF, 0x8AB7FF, 0x5A97FF, 0x2563EB, 0x1E4FD6, 0x1E40AF],
        dark:  [0x0F1A2B, 0x13264A, 0x1E3A8A, 0x2563EB, 0x3B82F6, 0x60A5FA, 0x93C5FD, 0xBFDBFE]
    )
    static let warning = Scale(
        light: [0xFFF7ED, 0xFFEDD5, 0xFED7AA, 0xFDBA74, 0xFB923C, 0xF97316, 0xEA580C, 0xC2410C],
        dark:  [0x2A1A10, 0x3A2312, 0x5A3416, 0x7A4518, 0xA85A1B, 0xF97316, 0xFF8A3D, 0xFF9A55]
    )
    static let error = Scale(
        light: [0xFEF2F2, 0xFEE2E2, 0xFECACA, 0xFCA5A5, 0xF87171, 0xDC2626, 0xDC2626, 0x991B1B],
        dark:  [0x2A1111, 0x3A1616, 0x5C1F1F, 0x8B2E2E, 0xDC2626, 0xF87171, 0xFCA5A5, 0xFECACA]
    )
}

// MARK: - Semantic tokens

/// hɛal design tokens, built from `EcoPalette`. The app is dark-first (`View.ecoTheme()` forces `.dark`),
/// but every token also has its light value from the Figma foundations.
enum Eco {
    // MARK: Brand
    static let primary   = EcoPalette.brand.s500          // main green
    static let secondary = EcoPalette.brand.s400
    static let accent    = Color(light: 0x2E7F4E, dark: 0x245A3E)
    static let highlight = Color(light: 0xB8EDD0, dark: 0x9FE5B9)

    // MARK: Backgrounds
    static let background    = EcoPalette.grey.s50                            // dark blue #0A0F1D / #F8F8F8
    static let surface       = Color(light: 0xFFFFFF, dark: 0x171C2E)         // cards, bars, sheets (neutral navy)
    static let surfaceRaised = Color(light: 0xF1F1F1, dark: 0x232941)         // nested elements on a card
    static let border        = Color(light: 0xE1E1E1, dark: 0x2C3350)
    static let selected      = primary.opacity(0.18)

    // MARK: Text
    static let textPrimary   = EcoPalette.grey.s700                           // #111217 / white
    static let textBody      = EcoPalette.grey.s600                           // #39383D / #E1E1E1
    static let textSecondary = Color(light: 0x72707A, dark: 0x9E9E9E)
    static let textHint      = Color(light: 0xC7C7C7, dark: 0x6F6F6F)
    static let onPrimary     = EcoPalette.darkBlue                            // dark text on the light green

    // MARK: Buttons — white in dark mode (navy in light mode); green stays an accent
    static let buttonFill = Color(light: 0x0A0F1D, dark: 0xFFFFFF)
    static let onButton   = Color(light: 0xFFFFFF, dark: 0x0A0F1D)

    // MARK: Status
    static let success = EcoPalette.success.s500
    static let error   = EcoPalette.error.s500
    static let warning = EcoPalette.warning.s500
    static let info    = EcoPalette.info.s500

    // MARK: Misc
    static let overlay = Color.black.opacity(0.5)

    /// Brand gradient for hero areas, badges and big action buttons.
    static let brandGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Spacing / radius tokens.
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
