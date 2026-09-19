import SwiftUI

/// Fonts: **Boathouse** for display / headlines / big numbers, **Inter** for titles, labels and body.
///
/// Font files live in `MyApp/Resources/Fonts/` and are registered through `UIAppFonts` in `project.yml`.
/// - `Inter.ttf` (variable font, OFL) is bundled.
/// - Boathouse is NOT bundled yet: add its files next to `Inter.ttf`, list them under `UIAppFonts`,
///   and set `EcoFontName.heading` to the font's family/PostScript name (Font Book → ⌘I).
///   Until then headings fall back to the system font, so nothing breaks.
enum EcoFontName {
    static let heading = "Boathouse"
    static let body = "Inter"
}

extension Font {
    private static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(EcoFontName.heading, size: size, relativeTo: style).weight(weight)
    }

    private static func body(_ size: CGFloat, relativeTo style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(EcoFontName.body, size: size, relativeTo: style).weight(weight)
    }

    // Display (Boathouse)
    static let ecoDisplayLarge  = heading(32, relativeTo: .largeTitle, weight: .bold)
    static let ecoDisplayMedium = heading(28, relativeTo: .largeTitle, weight: .bold)
    static let ecoDisplaySmall  = heading(24, relativeTo: .title, weight: .bold)

    // Headline (Boathouse)
    static let ecoHeadlineLarge  = heading(22, relativeTo: .title2, weight: .semibold)
    static let ecoHeadlineMedium = heading(20, relativeTo: .title3, weight: .semibold)
    static let ecoHeadlineSmall  = heading(18, relativeTo: .headline, weight: .semibold)

    // Title (Inter)
    static let ecoTitleLarge  = body(16, relativeTo: .headline, weight: .semibold)
    static let ecoTitleMedium = body(14, relativeTo: .subheadline, weight: .semibold)
    static let ecoTitleSmall  = body(12, relativeTo: .footnote, weight: .semibold)

    // Body (Inter)
    static let ecoBodyLarge  = body(16, relativeTo: .body)
    static let ecoBodyMedium = body(14, relativeTo: .subheadline)
    static let ecoBodySmall  = body(12, relativeTo: .caption)

    // Label (Inter)
    static let ecoLabelLarge  = body(14, relativeTo: .subheadline, weight: .medium)
    static let ecoLabelMedium = body(12, relativeTo: .caption, weight: .medium)
    static let ecoLabelSmall  = body(10, relativeTo: .caption2, weight: .medium)

    /// Hero number of the live recording screen (elapsed time).
    static let ecoHero = heading(56, relativeTo: .largeTitle, weight: .bold)

    /// Big numbers on stat tiles, live screen and badges (Boathouse).
    static let ecoStat = heading(28, relativeTo: .title, weight: .bold)
}
