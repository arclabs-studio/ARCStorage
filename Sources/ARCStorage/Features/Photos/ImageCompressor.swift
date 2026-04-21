import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Compresses full-size images to a maximum dimension and JPEG quality.
///
/// Used by `SwiftDataPhotoRepository` to keep inline SQLite storage lean.
/// Images are stored without `@Attribute(.externalStorage)` to avoid
/// SwiftData crashes on separate local-only containers.
enum ImageCompressor {
    /// Compresses image data to fit within `maxDimension` pixels (longest side)
    /// at the given JPEG `quality` (0.0–1.0).
    ///
    /// Returns the original data unchanged if:
    /// - The image is already smaller than `maxDimension`
    /// - The platform image initializer fails
    /// - The JPEG encoding fails
    static func compress(_ data: Data, maxDimension: CGFloat = 1200, quality: CGFloat = 0.8) -> Data {
        #if canImport(UIKit)
        return compressUIKit(data, maxDimension: maxDimension, quality: quality)
        #elseif canImport(AppKit)
        return compressAppKit(data, maxDimension: maxDimension, quality: quality)
        #else
        return data
        #endif
    }
}

// MARK: - Platform Implementations

extension ImageCompressor {
    #if canImport(UIKit)
    private static func compressUIKit(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            // Already small enough — just re-encode as JPEG
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: (size.width * ratio).rounded(),
                             height: (size.height * ratio).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
    #endif

    #if canImport(AppKit)
    private static func compressAppKit(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data {
        guard let image = NSImage(data: data) else { return data }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg,
                                                   properties: [.compressionFactor: quality])
            else { return data }
            return jpeg
        }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: (size.width * ratio).rounded(),
                             height: (size.height * ratio).rounded())
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg,
                                               properties: [.compressionFactor: quality])
        else { return data }
        return jpeg
    }
    #endif
}
