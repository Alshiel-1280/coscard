import Foundation
import UIKit

enum ImageResizer {
    /// 交換用サムネイル（256x256 前後、JPEG）
    static func thumbnailJPEGData(from image: UIImage, maxSide: CGFloat = 256, quality: CGFloat = 0.75) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newSize))
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return resized.jpegData(compressionQuality: quality)
    }
}
