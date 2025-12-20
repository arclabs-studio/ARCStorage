import Foundation

/// Repository implementation using UserDefaults storage.
///
/// Provides a convenient interface for persisting simple settings
/// and preferences.
///
/// ## Example
/// ```swift
/// struct AppSettings: Codable, Identifiable, Sendable {
///     let id: String
///     var theme: String
///     var fontSize: Int
/// }
///
/// let repository = UserDefaultsRepository<AppSettings>()
/// try await repository.save(settings)
/// ```
public actor UserDefaultsRepository<T: Codable & Sendable & Identifiable>: Repository where T.ID: LosslessStringConvertible {
    public typealias Entity = T

    private let storage: UserDefaultsStorage<T>
    private let cache: CacheManager<T.ID, T>

    /// Creates a new UserDefaults repository.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use
    ///   - keyPrefix: Prefix for storage keys
    ///   - cachePolicy: The caching policy
    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "ARCStorage",
        cachePolicy: CachePolicy = .default
    ) {
        self.storage = UserDefaultsStorage<T>(
            userDefaults: userDefaults,
            keyPrefix: keyPrefix
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
