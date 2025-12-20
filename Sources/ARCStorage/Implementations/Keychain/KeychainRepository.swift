import Foundation

/// Repository implementation using Keychain storage.
///
/// Provides secure persistence for sensitive data with a repository interface.
///
/// ## Example
/// ```swift
/// struct Credentials: Codable, Identifiable, Sendable {
///     let id: String
///     var username: String
///     var password: String
/// }
///
/// let repository = KeychainRepository<Credentials>(
///     service: "com.myapp.credentials"
/// )
/// try await repository.save(credentials)
/// ```
public actor KeychainRepository<T: Codable & Sendable & Identifiable>: Repository where T.ID: LosslessStringConvertible {
    public typealias Entity = T

    private let storage: KeychainStorage<T>
    private let cache: CacheManager<T.ID, T>

    /// Creates a new Keychain repository.
    ///
    /// - Parameters:
    ///   - service: The service identifier
    ///   - accessGroup: Optional access group
    ///   - cachePolicy: The caching policy
    public init(
        service: String,
        accessGroup: String? = nil,
        cachePolicy: CachePolicy = .default
    ) {
        self.storage = KeychainStorage<T>(
            service: service,
            accessGroup: accessGroup
        )
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
