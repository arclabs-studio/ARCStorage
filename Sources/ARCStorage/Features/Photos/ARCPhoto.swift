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
/// - `imageData`: Stored externally via `@Attribute(.externalStorage)`. Maps to
///   CKAsset when CloudKit sync is enabled. **Verify CKAsset mapping before shipping.**
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
    public var thumbnailData: Data?

    /// Full-size image stored as an external binary file.
    /// Maps to CKAsset in CloudKit when sync is enabled.
    @Attribute(.externalStorage) public var imageData: Data?

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
