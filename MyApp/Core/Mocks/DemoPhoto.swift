import UIKit

/// A procedurally-drawn placeholder "litter" photo, so Spot's "Use a demo photo"
/// button works on the simulator (no camera) without bundling a real asset.
enum DemoPhoto {
    static var image: UIImage {
        if let url = DemoPhotos.url("before_beach"), let data = try? Data(contentsOf: url), let real = UIImage(data: data) {
            return real
        }
        return placeholder
    }

    private static var placeholder: UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [UIColor(red: 0.19, green: 0.29, blue: 0.24, alpha: 1).cgColor,
                          UIColor(red: 0.10, green: 0.15, blue: 0.13, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 320, weight: .regular)
            if let symbol = UIImage(systemName: "trash.fill", withConfiguration: symbolConfig)?
                .withTintColor(UIColor(red: 0.65, green: 0.75, blue: 0.7, alpha: 0.9), renderingMode: .alwaysOriginal) {
                let rect = CGRect(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2,
                    width: symbol.size.width,
                    height: symbol.size.height
                )
                symbol.draw(in: rect)
            }
        }
    }
}
