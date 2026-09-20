import SwiftUI
import UIKit

/// Real `UIActivityViewController` share sheet + a best-effort Instagram Stories
/// pasteboard hand-off. The Instagram deep link needs a registered Meta App ID
/// (open decision in the plan, §10.5) which this project doesn't have, so on a
/// real device the app-availability check below will simply fail and we fall
/// through to the share sheet — no network call, nothing "faked" that a user
/// could mistake for a real post.
@MainActor
final class FakeShareService: ShareService {
    func shareToInstagramStory(image: UIImage?, videoURL: URL?, caption: String) async -> ShareOutcome {
        // Instagram only accepts Story shares that carry a registered Meta App ID (`source_application`).
        if let appID = AppInfo.instagramAppID,
           let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
           UIApplication.shared.canOpenURL(url) {
            let pasteboardItems: [String: Any] = {
                if let videoURL, let data = try? Data(contentsOf: videoURL) {
                    return ["com.instagram.sharedSticker.backgroundVideo": data]
                } else if let image, let data = image.pngData() {
                    return ["com.instagram.sharedSticker.backgroundImage": data]
                }
                return [:]
            }()

            guard !pasteboardItems.isEmpty else {
                return await presentShareSheet(image: image, videoURL: videoURL, caption: caption)
            }

            UIPasteboard.general.setItems(
                [pasteboardItems],
                options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
            )
            await UIApplication.shared.open(url)
            return .postedToInstagram
        }
        return await presentShareSheet(image: image, videoURL: videoURL, caption: caption)
    }

    private func presentShareSheet(image: UIImage?, videoURL: URL?, caption: String) async -> ShareOutcome {
        var items: [Any] = [caption]
        if let videoURL { items.append(videoURL) }
        if let image { items.append(image) }

        guard let presenter = UIApplication.shared.topViewController else { return .cancelled }
        return await withCheckedContinuation { continuation in
            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            sheet.completionWithItemsHandler = { _, completed, _, _ in
                continuation.resume(returning: completed ? .openedShareSheet : .cancelled)
            }
            presenter.present(sheet, animated: true)
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMost
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        if let presented = presentedViewController { return presented.topMost }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController { return visible.topMost }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController { return selected.topMost }
        return self
    }
}
