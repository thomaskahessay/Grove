import UIKit

/// Shared processing for user profile photos. The JPEG is stored in SwiftData and
/// uploaded to CloudKit as a CKAsset that every friend downloads, so keep it small.
enum ProfilePhoto {
    /// Longest edge of the stored photo, in pixels.
    static let maxPixelSize: CGFloat = 512

    /// Downscales to at most `maxPixelSize` pixels on the longest edge and encodes as JPEG.
    static func jpegData(from image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let ratio = min(1, maxPixelSize / max(pixelWidth, pixelHeight))
        let targetSize = CGSize(width: (pixelWidth * ratio).rounded(), height: (pixelHeight * ratio).rounded())

        // Scale 1 so the size above is pixels. The default format uses the screen
        // scale, which would render a 512pt image as 1536px on a 3x device.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    /// Re-encodes `data` if it's larger than `maxPixelSize` (photos saved by older
    /// builds were rendered at screen scale). Returns nil when no change is needed.
    static func downscaledIfOversized(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestEdge = max(image.size.width * image.scale, image.size.height * image.scale)
        guard longestEdge > maxPixelSize else { return nil }
        return jpegData(from: image)
    }
}
