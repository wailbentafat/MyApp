import SwiftUI

/// Headings use Poppins, body text uses Inter (same as the reference theme).
/// If the font files are not bundled, `Font.custom` silently falls back to the system font,
/// so the app still renders. To enable them: add Poppins-{Medium,SemiBold,Bold}.ttf and
/// Inter-Regular.ttf to the target and list them under `UIAppFonts` in `project.yml`.
extension Font {
    private static func poppins(_ weight: Font.Weight, _ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        let name: String
        switch weight {
        case .bold: name = "Poppins-Bold"
        case .semibold: name = "Poppins-SemiBold"
        default: name = "Poppins-Medium"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    private static func inter(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: style)
    }

    // Display
    static let ecoDisplayLarge  = poppins(.bold, 32, relativeTo: .largeTitle)
    static let ecoDisplayMedium = poppins(.bold, 28, relativeTo: .largeTitle)
    static let ecoDisplaySmall  = poppins(.bold, 24, relativeTo: .title)

    // Headline
    static let ecoHeadlineLarge  = poppins(.semibold, 22, relativeTo: .title2)
    static let ecoHeadlineMedium = poppins(.semibold, 20, relativeTo: .title3)
    static let ecoHeadlineSmall  = poppins(.semibold, 18, relativeTo: .headline)

    // Title
    static let ecoTitleLarge  = poppins(.semibold, 16, relativeTo: .headline)
    static let ecoTitleMedium = poppins(.semibold, 14, relativeTo: .subheadline)
    static let ecoTitleSmall  = poppins(.semibold, 12, relativeTo: .footnote)

    // Body
    static let ecoBodyLarge  = inter(16, relativeTo: .body)
    static let ecoBodyMedium = inter(14, relativeTo: .subheadline)
    static let ecoBodySmall  = inter(12, relativeTo: .caption)

    // Label
    static let ecoLabelLarge  = poppins(.medium, 14, relativeTo: .subheadline)
    static let ecoLabelMedium = poppins(.medium, 12, relativeTo: .caption)
    static let ecoLabelSmall  = poppins(.medium, 10, relativeTo: .caption2)

    /// Big numbers on stat tiles and badges.
    static let ecoStat = poppins(.bold, 28, relativeTo: .title)
}
