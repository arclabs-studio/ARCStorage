import ARCLogger
import Foundation
import SwiftData

/// SwiftData-backed implementation of `PhotoRepository`.
///
/// Uses the app's existing `ModelContainer` to persist `ARCPhoto` entities.
/// Must be created at the composition root alongside `SwiftDataRepository`.
///
/// ## Schema Registration
/// Ensure `ARCPhoto.self` is included in the `Schema` passed to `SwiftDataConfiguration`:
/// ```swift
/// let schema = Schema([RestaurantModel.self, VisitModel.self, ARCPhoto.self])
/// ```
@MainActor
public final class SwiftDataPhotoRepository: PhotoRepository {
    // MARK: - Properties

    private let modelContext: ModelContext
    private let thumbnailGenerator = ThumbnailGenerator()
    private let logger = ARCLogger(subsystem: "com.arclabs.ARCStorage", category: "PhotoRepository")

    // MARK: - Initialization

    public init(modelContainer: ModelContainer) {
        modelContext = modelContainer.mainContext
    }

    // MARK: - PhotoRepository

    public func add(imageData: Data, caption: String?, sortOrder: Int) throws -> ARCPhoto {
        let thumbnail = try thumbnailGenerator.generateSynchronously(from: imageData)

        let photo = ARCPhoto(thumbnailData: thumbnail,
                             imageData: imageData,
                             caption: caption,
                             sortOrder: sortOrder)
        modelContext.insert(photo)

        do {
            try modelContext.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }

        logger.debug("ARCPhoto saved: \(photo.id)")
        return photo
    }

    public func photos(withIDs ids: [PersistentIdentifier]) throws -> [ARCPhoto] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<ARCPhoto>()
        let all = try modelContext.fetch(descriptor)
        return all.filter { idSet.contains($0.persistentModelID) }
    }

    public func delete(id: PersistentIdentifier) throws {
        let matches = try photos(withIDs: [id])
        guard let photo = matches.first else {
            throw StorageError.entityNotFound(id: id)
        }
        modelContext.delete(photo)
        do {
            try modelContext.save()
        } catch {
            throw StorageError.deleteFailed(underlying: error)
        }
    }

    public func deleteAll(_ photos: [ARCPhoto]) throws {
        for photo in photos {
            modelContext.delete(photo)
        }
        do {
            try modelContext.save()
        } catch {
            throw StorageError.deleteFailed(underlying: error)
        }
    }
}
