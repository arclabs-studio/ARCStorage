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
    /// - Throws: ``StorageError`` if the fetch operation fails
    public func fetch(matching predicate: Predicate<T>) throws -> [T] {
        try storage.fetch(matching: predicate)
    }

    /// Fetches all entities with relationship prefetching.
    ///
    /// Use this method to avoid N+1 query problems when you need to access
    /// relationships on the fetched entities.
    ///
    /// - Parameter relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of all entities with prefetched relationships
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// // Prefetch reviews when fetching restaurants
    /// let restaurants = try repository.fetchAll(
    ///     prefetching: [\Restaurant.reviews]
    /// )
    /// ```
    public func fetchAll(
        prefetching relationshipKeyPaths: [PartialKeyPath<T>]
    ) throws -> [T] {
        try storage.fetchAll(prefetching: relationshipKeyPaths)
    }

    /// Fetches entities matching a predicate with relationship prefetching.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter entities
    ///   - relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of matching entities with prefetched relationships
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// let predicate = #Predicate<Restaurant> { $0.rating >= 4.0 }
    /// let topRestaurants = try repository.fetch(
    ///     matching: predicate,
    ///     prefetching: [\Restaurant.reviews]
    /// )
    /// ```
    public func fetch(
        matching predicate: Predicate<T>,
        prefetching relationshipKeyPaths: [PartialKeyPath<T>]
    ) throws -> [T] {
        try storage.fetch(matching: predicate, prefetching: relationshipKeyPaths)
    }

    /// Fetches entities with full configuration options.
    ///
    /// This method provides complete control over the fetch operation, including
    /// filtering, sorting, pagination, and relationship prefetching.
    ///
    /// - Parameters:
    ///   - predicate: Optional predicate to filter entities
    ///   - sortDescriptors: Sort descriptors for ordering results
    ///   - fetchLimit: Maximum number of entities to fetch
    ///   - fetchOffset: Number of entities to skip (for pagination)
    ///   - relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of entities matching the criteria
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// let predicate = #Predicate<Restaurant> { $0.isOpen }
    /// let restaurants = try repository.fetch(
    ///     matching: predicate,
    ///     sortedBy: [Foundation.SortDescriptor(\.rating, order: .reverse)],
    ///     limit: 20,
    ///     offset: 0,
    ///     prefetching: [\Restaurant.reviews]
    /// )
    /// ```
    public func fetch(
        matching predicate: Predicate<T>? = nil,
        sortedBy sortDescriptors: [Foundation.SortDescriptor<T>] = [],
        limit fetchLimit: Int? = nil,
        offset fetchOffset: Int? = nil,
        prefetching relationshipKeyPaths: [PartialKeyPath<T>] = []
    ) throws -> [T] {
        try storage.fetch(
            matching: predicate,
            sortedBy: sortDescriptors,
            limit: fetchLimit,
            offset: fetchOffset,
            prefetching: relationshipKeyPaths
        )
    }

    /// Saves multiple entities in a batch.
    ///
    /// - Parameter entities: Entities to save
    /// - Throws: ``StorageError`` if the save operation fails
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
