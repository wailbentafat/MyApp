import Foundation
import UIKit

/// Stands in for Supabase Storage: writes captured photos to the app's local
/// Documents directory and hands back a real (but local-only) file URL. The rest
/// of the app just holds a `URL?`, so swapping this for real upload later is a
/// one-file change.
enum FakePhotoStore {
    static let shared = FakePhotoStoreImpl()
}

final class FakePhotoStoreImpl: @unchecked Sendable {
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("SpotPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    func save(_ data: Data?) throws -> URL? {
        guard let data else { return nil }
        let url = directory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    func loadImage(_ url: URL?) -> UIImage? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
