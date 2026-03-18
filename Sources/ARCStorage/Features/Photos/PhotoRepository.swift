import Foundation
import SwiftData

/// A repository for managing photo attachments associated with SwiftData entities.
///
/// ## Threading
/// Implementations are `@MainActor`-isolated because `ARCPhoto` is a `@Model` class
/// that cannot conform to `Sendable` in Swift 6 strict concurrency mode.
/// This matches the `SwiftDataRepository<T>` pattern used throughout ARCStorage.
///
/// ## Usage
/// ```swift
/// // In AppCoordinator (Composition Root)
/// let photoRepo = SwiftDataPhotoRepository(modelContainer: container)
///
/// // In @MainActor ViewModel
/// let photo = try photoRepo.add(imageData: jpeg, caption: "Dinner", sortOrder: 0)
/// let photos = try photoRepo.photos(withIDs: [visit.persistentModelID])
/// ```
@MainActor
public protocol PhotoRepository: AnyObject {
    /// Generates a thumbnail, stores the photo, and returns the persisted `ARCPhoto`.
    func add(imageData: Data, caption: String?, sortOrder: Int) throws -> ARCPhoto

    /// Fetches all photos whose `persistentModelID` is in the provided set.
    /// Use the parent entity's relationship directly in most cases; this is
    /// useful for batch fetch without loading the parent entity.
    func photos(withIDs ids: [PersistentIdentifier]) throws -> [ARCPhoto]

    /// Deletes a single photo by its persistent identifier.
    func delete(id: PersistentIdentifier) throws

    /// Deletes all provided photos in a single batch.
    func deleteAll(_ photos: [ARCPhoto]) throws
}
