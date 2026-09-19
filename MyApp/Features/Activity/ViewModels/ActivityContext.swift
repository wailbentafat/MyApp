import Foundation

/// How an activity is started: free, or attached to a Clean-Up (whose Before photo and location it uses).
enum ActivityContext: Hashable, Sendable {
    case free
    case cleanUp(CleanUp)

    var cleanUp: CleanUp? {
        if case .cleanUp(let cleanUp) = self { cleanUp } else { nil }
    }
}

extension ImpactLog {
    /// `itemCounts` is keyed by `WasteType.rawValue` (shared contract).
    func count(for type: WasteType) -> Int { itemCounts[type.rawValue] ?? 0 }
    var totalItems: Int { itemCounts.values.reduce(0, +) }
    var isEmpty: Bool { bags == 0 && kg == 0 && totalItems == 0 }
}
