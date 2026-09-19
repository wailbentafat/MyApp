import Foundation

enum WasteCategory: String, Codable, CaseIterable, Hashable, Sendable, CodingKeyRepresentable {
    case plastic, glass, metal, paper, organic, bulky, hazardous, other

    var label: String {
        switch self {
        case .plastic: "Plastic"
        case .glass: "Glass"
        case .metal: "Metal"
        case .paper: "Paper"
        case .organic: "Organic"
        case .bulky: "Bulky item"
        case .hazardous: "Hazardous"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .plastic: "waterbottle"
        case .glass: "wineglass"
        case .metal: "wrench.and.screwdriver"
        case .paper: "doc"
        case .organic: "leaf"
        case .bulky: "sofa"
        case .hazardous: "exclamationmark.triangle"
        case .other: "trash"
        }
    }
}

/// What the user collected during an activity.
struct ImpactLog: Codable, Hashable, Sendable {
    var bags: Int = 0
    var kg: Double = 0
    var items: [WasteCategory: Int] = [:]

    var isEmpty: Bool { bags == 0 && kg == 0 && items.values.allSatisfy { $0 == 0 } }
    var totalItems: Int { items.values.reduce(0, +) }
}
