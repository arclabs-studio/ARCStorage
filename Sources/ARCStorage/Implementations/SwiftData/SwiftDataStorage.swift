import Foundation
import SwiftData

/// SwiftData-backed storage implementation.
///
/// Uses `@ModelActor` for thread-safe ModelContext operations.
/// Supports all CRUD operations with SwiftData's persistence layer.
///
/// ## Topics
/// ### Initialization
/// - ``init(modelContainer:)``
///
/// ### Performance
/// For optimal fetch performance, add an index to your model's id property:
/// ```swift
/// @Model
/// final class Restaurant: Identifiable, Codable {
///     @Attribute(.unique)
///     var id: UUID
///     var name: String
/// }
/// ```
///
/// ## Example
/// ```swift
/// @Model
/// final class Restaurant: Identifiable, Codable {
///     var id: UUID
///     var name: String
/// }
///
/// let container = try ModelContainer(for: Restaurant.self)
/// let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
/// ```
@ModelActor
public actor SwiftDataStorage<T>: StorageProvider where T: PersistentModel & Identifiable & Codable & Sendable,
T.ID: Sendable & Hashable {
    public typealias Entity = T

    /// Tracks registered objects for faster lookups.
    private var registeredObjects: [T.ID: T] = [:]

    public func save(_ entity: T) async throws {
        modelContext.insert(entity)
        registeredObjects[entity.id] = entity
        try saveContext()
    }

    public func saveAll(_ entities: [T]) async throws {
        for entity in entities {
            modelContext.insert(entity)
            registeredObjects[entity.id] = entity
        }
        try saveContext()
    }

    public func fetch(id: T.ID) async throws -> T? {
        // 1. Check registered objects first (O(1) lookup)
        if let cached = registeredObjects[id] {
            // Verify it's still valid in the context
            if !cached.isDeleted {
                return cached
            }
            registeredObjects.removeValue(forKey: id)
        }

        // 2. Use enumeration to find the entity with early exit
        //    This is more efficient than fetching all when the entity is near the start
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 100 // Batch size for enumeration

        var offset = 0
        while true {
            descriptor.fetchOffset = offset
            let batch = try modelContext.fetch(descriptor)

            if batch.isEmpty {
                return nil
            }

            for entity in batch where entity.id == id {
                registeredObjects[id] = entity
                return entity
            }

            offset += batch.count

            // If we got fewer than the limit, we've reached the end
            if batch.count < 100 {
                return nil
            }
        }
    }

    public func fetchAll() async throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try modelContext.fetch(descriptor)
    }

    public func fetch(matching predicate: Predicate<T>) async throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    public func delete(id: T.ID) async throws {
        guard let entity = try await fetch(id: id) else {
            throw StorageError.entityNotFound(id: id)
        }
        modelContext.delete(entity)
        registeredObjects.removeValue(forKey: id)
        try saveContext()
    }

    public func deleteAll() async throws {
        let entities = try await fetchAll()
        for entity in entities {
            modelContext.delete(entity)
        }
        registeredObjects.removeAll()
        try saveContext()
    }

    public func performTransaction<Result: Sendable>(
        _ block: @Sendable () async throws -> Result
    ) async throws -> Result {
        do {
            let result = try await block()
            try saveContext()
            return result
        } catch {
            modelContext.rollback()
            throw StorageError.transactionFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func saveContext() throws {
        do {
            try modelContext.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }
}
