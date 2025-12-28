import SwiftData
import Foundation

/// SwiftData-backed storage implementation.
///
/// Uses `@ModelActor` for thread-safe ModelContext operations.
/// Supports all CRUD operations with SwiftData's persistence layer.
///
/// ## Topics
/// ### Initialization
/// - ``init(modelContainer:)``
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
public actor SwiftDataStorage<T>: StorageProvider where T: PersistentModel & Identifiable & Codable & Sendable, T.ID: Sendable & Hashable {
    public typealias Entity = T

    public func save(_ entity: T) async throws {
        modelContext.insert(entity)
        try saveContext()
    }

    public func saveAll(_ entities: [T]) async throws {
        for entity in entities {
            modelContext.insert(entity)
        }
        try saveContext()
    }

    public func fetch(id: T.ID) async throws -> T? {
        // Fetch all and filter by ID to avoid #Predicate issues with generics
        let descriptor = FetchDescriptor<T>()
        let entities = try modelContext.fetch(descriptor)
        return entities.first { $0.id == id }
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
        try saveContext()
    }

    public func deleteAll() async throws {
        let entities = try await fetchAll()
        for entity in entities {
            modelContext.delete(entity)
        }
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
