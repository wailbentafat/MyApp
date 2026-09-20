import Foundation

/// Lets a bare `UUID` drive `.sheet(item:)` / `.fullScreenCover(item:)` (e.g. "open the post with this id").
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
