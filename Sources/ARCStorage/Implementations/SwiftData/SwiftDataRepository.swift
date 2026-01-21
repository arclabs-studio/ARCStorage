import Foundation
import SwiftData

/// Repository implementation for SwiftData entities.
///
/// Provides a high-level interface for domain operations with SwiftData persistence.
///
/// ## Swift 6 Concurrency Compatibility
///
/// This repository is isolated to `@MainActor` because SwiftData `@Model` classes
/// cannot conform to `Sendable` in Swift 6 strict concurrency mode.
///
/// This repository does **not** conform to ``Repository`` because that protocol
/// requires `Sendable` entities.
///
/// Unlike other repository implementations, this class does not use ``CacheManager``
/// because `CacheManager` requires `Sendable` values. However, SwiftData provides
/// its own internal caching (object faulting), so explicit caching is not necessary.
///
/// ## Topics
/// ### Initialization
/// - ``init(storage:)``
///
/// ## Example
/// ```swift
/// let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
/// let repository = SwiftDataRepository(storage: storage)
///
/// // Use in ViewModel (must be @MainActor)
/// let restaurants = try repository.fetchAll()
/// ```
@MainActor
public final class SwiftDataRepository<T: SwiftDataEntity> {
    private let storage: SwiftDataStorage<T>

    /// Creates a new repository.
    ///
    /// - Parameters:
    ///   - storage: The underlying SwiftData storage
    public init(storage: SwiftDataStorage<T>) {
        self.storage = storage
    }

    /// Saves or updates an entity.
    ///
    /// - Parameter entity: The entity to save
    /// - Throws: ``StorageError`` if the operation fails
    public func save(_ entity: T) throws {
        try storage.save(entity)
    }

    /// Fetches all entities.
    ///
    /// - Returns: Array of all entities
    /// - Throws: ``StorageError`` if the operation fails
    public func fetchAll() throws -> [T] {
        try storage.fetchAll()
    }

    /// Fetches an entity by its identifier.
    ///
    /// - Parameter id: The unique identifier
    /// - Returns: The entity if found, `nil` otherwise
    /// - Throws: ``StorageError`` if the operation fails
    public func fetch(id: T.ID) throws -> T? {
        try storage.fetch(id: id)
    }

    /// Deletes an entity by its identifier.
    ///
    /// - Parameter id: The unique identifier
    /// - Throws: ``StorageError`` if the operation fails
    public func delete(id: T.ID) throws {
        try storage.delete(id: id)
    }

    /// Fetches entities matching a predicate.
    ///
    /// - Parameter predicate: The predicate to match
    /// - Returns: Array of matching entities
    public func fetch(matching predicate: Predicate<T>) throws -> [T] {
        try storage.fetch(matching: predicate)
    }

    /// Saves multiple entities in a batch.
    ///
    /// - Parameter entities: Entities to save
    public func saveAll(_ entities: [T]) throws {
        try storage.saveAll(entities)
    }

    /// Deletes all entities.
    ///
    /// - Warning: This operation cannot be undone
    /// - Throws: ``StorageError`` if the delete operation fails
    public func deleteAll() throws {
        try storage.deleteAll()
    }
}
