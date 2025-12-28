import SwiftData
import Foundation

/// Repository implementation with caching on top of SwiftDataStorage.
///
/// Provides a high-level interface for domain operations with automatic
/// caching using the cache-aside pattern.
///
/// ## Topics
/// ### Initialization
/// - ``init(storage:cachePolicy:)``
///
/// ## Example
/// ```swift
/// let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
/// let repository = SwiftDataRepository(
///     storage: storage,
///     cachePolicy: .default
/// )
///
/// // Use in ViewModel
/// let restaurants = try await repository.fetchAll()
/// ```
public actor SwiftDataRepository<T>: Repository where T: PersistentModel & Identifiable & Codable & Sendable, T.ID: Sendable & Hashable {
    public typealias Entity = T

    private let storage: SwiftDataStorage<T>
    private let cache: CacheManager<T.ID, T>

    /// Creates a new repository.
    ///
    /// - Parameters:
    ///   - storage: The underlying SwiftData storage
    ///   - cachePolicy: The caching policy to use
    public init(
        storage: SwiftDataStorage<T>,
        cachePolicy: CachePolicy = .default
    ) {
        self.storage = storage
        self.cache = CacheManager(policy: cachePolicy)
    }

    public func save(_ entity: T) async throws {
        try await storage.save(entity)
        await cache.set(entity, for: entity.id)
    }

    public func fetchAll() async throws -> [T] {
        let entities = try await storage.fetchAll()

        // Update cache with fetched entities
        for entity in entities {
            await cache.set(entity, for: entity.id)
        }

        return entities
    }

    public func fetch(id: T.ID) async throws -> T? {
        // Check cache first
        if let cached = await cache.get(id) {
            return cached
        }

        // Fetch from storage
        guard let entity = try await storage.fetch(id: id) else {
            return nil
        }

        // Update cache
        await cache.set(entity, for: id)

        return entity
    }

    public func delete(id: T.ID) async throws {
        try await storage.delete(id: id)
        await cache.invalidate(id)
    }

    public func invalidateCache() async {
        await cache.invalidate()
    }
}

extension SwiftDataRepository {
    /// Fetches entities matching a predicate.
    ///
    /// This is a convenience method that bypasses caching for complex queries.
    ///
    /// - Parameter predicate: The predicate to match
    /// - Returns: Array of matching entities
    public func fetch(matching predicate: Predicate<T>) async throws -> [T] {
        try await storage.fetch(matching: predicate)
    }

    /// Saves multiple entities in a batch.
    ///
    /// - Parameter entities: Entities to save
    public func saveAll(_ entities: [T]) async throws {
        try await storage.saveAll(entities)

        // Update cache
        for entity in entities {
            await cache.set(entity, for: entity.id)
        }
    }
}
