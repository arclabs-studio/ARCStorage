import Foundation
import SwiftData

/// SwiftData-backed storage implementation.
///
/// Provides thread-safe ModelContext operations isolated to the MainActor.
/// Supports all CRUD operations with SwiftData's persistence layer.
///
/// ## Swift 6 Concurrency Compatibility
///
/// This storage is isolated to `@MainActor` because SwiftData `@Model` classes
/// cannot conform to `Sendable` in Swift 6 strict concurrency mode. The `@Model`
/// macro generates conformances isolated to the main actor, so all SwiftData
/// operations must occur on the main actor.
///
/// This storage does **not** conform to ``StorageProvider`` because that protocol
/// requires `Sendable` entities.
///
/// Use ``SwiftDataEntity`` protocol for your models instead of requiring `Sendable`.
///
/// ## Topics
/// ### Initialization
/// - ``init(modelContainer:)``
///
/// ### Performance
/// For optimal fetch performance, add an index to your model's id property:
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID
///     var name: String
/// }
/// ```
///
/// ## Example
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     var id: UUID
///     var name: String
/// }
///
/// let container = try ModelContainer(for: Restaurant.self)
/// let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
/// ```
@MainActor
public final class SwiftDataStorage<T: SwiftDataEntity> {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// Tracks registered objects for faster lookups.
    private var registeredObjects: [T.ID: T] = [:]

    /// Creates a new SwiftData storage.
    ///
    /// - Parameter modelContainer: The model container to use for persistence
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    public func save(_ entity: T) throws {
        modelContext.insert(entity)
        registeredObjects[entity.id] = entity
        try saveContext()
    }

    public func saveAll(_ entities: [T]) throws {
        for entity in entities {
            modelContext.insert(entity)
            registeredObjects[entity.id] = entity
        }
        try saveContext()
    }

    public func fetch(id: T.ID) throws -> T? {
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

    public func fetchAll() throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try modelContext.fetch(descriptor)
    }

    public func fetch(matching predicate: Predicate<T>) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    public func delete(id: T.ID) throws {
        guard let entity = try fetch(id: id) else {
            throw StorageError.entityNotFound(id: id)
        }
        modelContext.delete(entity)
        registeredObjects.removeValue(forKey: id)
        try saveContext()
    }

    public func deleteAll() throws {
        let entities = try fetchAll()
        for entity in entities {
            modelContext.delete(entity)
        }
        registeredObjects.removeAll()
        try saveContext()
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
