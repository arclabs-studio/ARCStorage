import Foundation

/// Repository implementation using in-memory storage.
///
/// Useful for testing and prototyping without persistence.
///
/// ## Example
/// ```swift
/// let repository = InMemoryRepository<Restaurant>()
/// try await repository.save(restaurant)
/// let all = try await repository.fetchAll()
/// ```
public actor InMemoryRepository<T: Codable & Sendable & Identifiable>: Repository where T.ID: Sendable & Hashable {
    public typealias Entity = T

    private let storage: InMemoryStorage<T>
    private let cache: CacheManager<T.ID, T>

    /// Creates a new in-memory repository.
    ///
    /// - Parameter cachePolicy: The caching policy to use
    public init(cachePolicy: CachePolicy = .default) {
        self.storage = InMemoryStorage<T>()
        self.cache = CacheManager(policy: cachePolicy)
    }

    public func save(_ entity: T) async throws {
        try await storage.save(entity)
        await cache.set(entity, for: entity.id)
    }

    public func fetchAll() async throws -> [T] {
        let entities = try await storage.fetchAll()

        for entity in entities {
            await cache.set(entity, for: entity.id)
        }

        return entities
    }

    public func fetch(id: T.ID) async throws -> T? {
        if let cached = await cache.get(id) {
            return cached
        }

        guard let entity = try await storage.fetch(id: id) else {
            return nil
        }

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

extension InMemoryRepository {
    /// Provides direct access to the underlying storage for testing.
    public var underlyingStorage: InMemoryStorage<T> {
        storage
    }
}
