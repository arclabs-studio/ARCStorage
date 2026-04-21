import Foundation
import SwiftData

/// A photo attachment that can be associated with any SwiftData entity via a relationship.
///
/// ## CloudKit Compatibility
/// All properties have defaults or are optional (required for CloudKit sync).
/// `@Attribute(.unique)` is intentionally omitted (incompatible with CloudKit).
///
/// ## Storage
/// - `thumbnailData`: Inline in SQLite (< 50 KB target). Fast list rendering.
/// - `imageData`: Stored inline in SQLite. Consumer apps should pre-compress images
///   (e.g. JPEG ≤ 1200px max dimension) before persisting to keep the store lean.
///
/// ## Relationship Setup (Consumer App)
/// Register `ARCPhoto.self` in your app's `Schema` alongside your entity:
/// ```swift
/// @Model final class VisitModel: SwiftDataEntity {
///     @Relationship(deleteRule: .cascade) var photos: [ARCPhoto]? = []
/// }
/// let schema = Schema([VisitModel.self, ARCPhoto.self])
/// ```
@Model
public final class ARCPhoto: SwiftDataEntity {
    // MARK: - Properties (all with defaults for CloudKit compat)

    public var id = UUID()

    /// Compressed JPEG thumbnail (≤ 200×200px, targeting < 50 KB).
    ///
    /// - Important: Stored inline in the CloudKit record when sync is enabled.
    ///   CloudKit has a 1 MB total per-record limit for inline fields.
    ///   Keep thumbnails under 50 KB to leave room for other fields.
    public var thumbnailData: Data?

    /// Full-size image data (pre-compressed JPEG recommended).
    /// Stored inline — no `@Attribute(.externalStorage)` to avoid SwiftData
    /// crashes on separate local-only containers.
    public var imageData: Data?

    /// Optional user-provided caption.
    public var caption: String?

    /// Creation date for chronological ordering.
    public var createdAt: Date? = Date()

    /// Sort order within parent entity's photo collection.
    public var sortOrder: Int = 0

    // MARK: - Initialization

    public init(id: UUID = UUID(),
                thumbnailData: Data? = nil,
                imageData: Data? = nil,
                caption: String? = nil,
                createdAt: Date? = Date(),
                sortOrder: Int = 0) {
        self.id = id
        self.thumbnailData = thumbnailData
        self.imageData = imageData
        self.caption = caption
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
