import ARCLogger
import Foundation
import SwiftData

/// SwiftData-backed implementation of `PhotoRepository`.
///
/// Photos must live in a **separate local-only container** from any CloudKit-synced
/// models. CloudKit requires every relationship to have a declared inverse; because
/// `ARCPhoto` has no inverse back to the visit model, including it in a CloudKit
/// container triggers a schema validation crash at launch.
///
/// ## Setup
/// Create a dedicated photo container using `SwiftDataConfiguration(storeName:)` so
/// it writes to a different backing file than your CloudKit store:
/// ```swift
/// let photoConfig = SwiftDataConfiguration(
///     schema: Schema([ARCPhoto.self]),
///     storeName: "arc-photos"          // → arc-photos.store, not default.store
/// )
/// let photoContainer = try photoConfig.makeContainer()
/// let photoRepository = SwiftDataPhotoRepository(modelContainer: photoContainer)
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

    public func add(imageData: Data, caption: String?, sortOrder: Int) async throws -> ARCPhoto {
        // Hop to the ThumbnailGenerator actor (cooperative thread pool) for CPU-bound
        // image work, then automatically resume on @MainActor for SwiftData operations.
        let thumbnail = try await thumbnailGenerator.generate(from: imageData)

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

    /// - Note: Fetches all `ARCPhoto` records then filters in memory, because
    ///   `PersistentIdentifier` cannot be used in a SwiftData `#Predicate`.
    ///   Prefer the parent entity's relationship property (e.g. `visit.photos`)
    ///   for large collections.
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
