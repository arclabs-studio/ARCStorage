import Foundation

/// In-memory storage implementation for testing.
///
/// This storage provider keeps all data in memory and provides no persistence.
/// It's perfect for unit tests where you need fast, isolated storage.
///
/// ## Topics
/// ### Initialization
/// - ``init()``
///
/// ## Example
/// ```swift
/// let storage = InMemoryStorage<Restaurant>()
/// let restaurant = Restaurant(id: UUID(), name: "Test")
/// try await storage.save(restaurant)
/// ```
public actor InMemoryStorage<T: Codable & Sendable & Identifiable>: StorageProvider where T.ID: Sendable & Hashable {
    public typealias Entity = T

    private var entities: [T.ID: T] = [:]

    /// Creates a new in-memory storage.
    public init() {}

    public func save(_ entity: T) async throws {
        entities[entity.id] = entity
    }

    public func saveAll(_ entities: [T]) async throws {
        for entity in entities {
            self.entities[entity.id] = entity
        }
    }

    public func fetch(id: T.ID) async throws -> T? {
        entities[id]
    }

    public func fetchAll() async throws -> [T] {
        Array(entities.values)
    }

    public func fetch(matching predicate: Predicate<T>) async throws -> [T] {
        let allEntities = Array(entities.values)
        return try allEntities.filter { entity in
            try predicate.evaluate(entity)
        }
    }

    public func delete(id: T.ID) async throws {
        guard entities[id] != nil else {
            throw StorageError.entityNotFound(id: id)
        }
        entities.removeValue(forKey: id)
    }

    public func deleteAll() async throws {
        entities.removeAll()
    }

    public func performTransaction<Result: Sendable>(
        _ block: @Sendable () async throws -> Result
    ) async throws -> Result {
        let snapshot = entities

        do {
            return try await block()
        } catch {
            entities = snapshot
            throw StorageError.transactionFailed(underlying: error)
        }
    }
}
