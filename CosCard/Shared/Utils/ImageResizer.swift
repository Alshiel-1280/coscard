import Foundation
import UIKit

enum ImageResizer {
    /// 交換用サムネイル（256x256 前後、JPEG）
    static func thumbnailJPEGData(from image: UIImage, maxSide: CGFloat = 256, quality: CGFloat = 0.75) -> Data? {
        resizedJPEGData(from: image, maxSide: maxSide, quality: quality)
    }

    /// 名刺画像はMPCで送るため、見読みに足る範囲で軽量化する。
    static func businessCardJPEGData(
        from image: UIImage,
        maxSide: CGFloat = 1024,
        quality: CGFloat = 0.8,
        maxBytes: Int = 350_000
    ) -> Data? {
        var currentMaxSide = maxSide
        var currentQuality = quality
        for _ in 0 ..< 8 {
            guard let data = resizedJPEGData(from: image, maxSide: currentMaxSide, quality: currentQuality) else {
                return nil
            }
            if data.count <= maxBytes {
                return data
            }
            if currentQuality > 0.45 {
                currentQuality -= 0.1
            } else {
                currentMaxSide *= 0.82
            }
        }
        guard let fallback = resizedJPEGData(from: image, maxSide: 640, quality: 0.45),
              fallback.count <= maxBytes
        else {
            return nil
        }
        return fallback
    }

    private static func resizedJPEGData(from image: UIImage, maxSide: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.jpegData(withCompressionQuality: quality) { ctx in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
