import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Internal utility for generating compressed JPEG thumbnails.
///
/// Target: ≤ 200×200px, < 50 KB, safe to call off the main thread.
actor ThumbnailGenerator {
    // MARK: - Constants

    static let maxDimension: CGFloat = 200
    static let jpegQuality: CGFloat = 0.4

    // MARK: - API

    /// Generates a thumbnail (actor-hop at call site from async contexts).
    func generate(from data: Data) throws -> Data {
        try _generate(from: data)
    }

    /// Convenience for synchronous call sites within the same actor context.
    nonisolated func generateSynchronously(from data: Data) throws -> Data {
        try _generate(from: data)
    }
}

// MARK: - Platform Implementation

extension ThumbnailGenerator {
    private nonisolated func _generate(from data: Data) throws -> Data {
        #if canImport(UIKit)
        return try generateUIKit(from: data)
        #elseif canImport(AppKit)
        return try generateAppKit(from: data)
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    private nonisolated func generateUIKit(from data: Data) throws -> Data {
        guard let source = UIImage(data: data) else {
            throw StorageError.invalidData
        }
        let size = thumbnailSize(for: source.size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: ThumbnailGenerator.jpegQuality) else {
            throw StorageError.invalidData
        }
        return jpeg
    }
    #endif

    #if canImport(AppKit)
    private nonisolated func generateAppKit(from data: Data) throws -> Data {
        guard let source = NSImage(data: data) else {
            throw StorageError.invalidData
        }
        let size = thumbnailSize(for: source.size)
        let resized = NSImage(size: size)
        resized.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: size),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy,
                    fraction: 1.0)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg,
                                               properties: [.compressionFactor: ThumbnailGenerator.jpegQuality])
        else {
            throw StorageError.invalidData
        }
        return jpeg
    }
    #endif

    private nonisolated func thumbnailSize(for original: CGSize) -> CGSize {
        let max = ThumbnailGenerator.maxDimension
        guard original.width > max || original.height > max else { return original }
        let ratio = min(max / original.width, max / original.height)
        return CGSize(width: (original.width * ratio).rounded(),
                      height: (original.height * ratio).rounded())
    }
}
