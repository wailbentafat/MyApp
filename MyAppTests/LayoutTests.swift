import SwiftUI
import UIKit
import XCTest
@testable import MyApp

/// Regression tests for the "feed card sticks to the right edge" bug: content must never be wider than the column.
@MainActor
final class LayoutTests: XCTestCase {
    private func width<V: View>(of view: V, in available: CGFloat = 358) -> CGFloat {
        let host = UIHostingController(rootView: view.frame(maxWidth: available).environment(\.colorScheme, .dark))
        return host.sizeThatFits(in: CGSize(width: available, height: 2000)).width
    }

    func testFeedPostCardFitsTheColumn() throws {
        let post = try XCTUnwrap(Fixtures.seedFeedPosts().first)
        XCTAssertNotNil(FakePhotoStore.shared.loadImage(post.beforePhotoURL), "test needs the real bundled photo")
        let card = ActivityPostCard(post: post, onKudos: {}, onShare: {})
        XCTAssertLessThanOrEqual(width(of: card), 358.5)
    }

    func testCleanUpCardFitsTheColumn() throws {
        let cleanUp = try XCTUnwrap(Fixtures.seedCleanUps().first)
        let card = CleanUpCard(cleanUp: cleanUp, subtitle: "112 m away", rsvpTitle: "RSVP", isGoing: false, onOpen: {}, onRSVP: {})
        XCTAssertLessThanOrEqual(width(of: card), 358.5)
    }

    func testPhotoNeverWidensItsParent() throws {
        let image = try XCTUnwrap(FakePhotoStore.shared.loadImage(DemoPhotos.url("before_river")))
        let row = HStack(spacing: 8) {
            EcoPhoto(image: image, height: 150)
            EcoPhoto(image: image, height: 150)
        }
        XCTAssertLessThanOrEqual(width(of: row), 358.5)
    }
}
