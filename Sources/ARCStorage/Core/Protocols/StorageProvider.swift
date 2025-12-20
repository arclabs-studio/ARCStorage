import Foundation

/// Primary storage abstraction protocol.
///
/// `StorageProvider` defines the contract for any storage mechanism in ARCStorage.
/// Implementations handle the actual persistence (SwiftData, UserDefaults, Keychain, etc.).
///
/// ## Topics
/// ### Saving Data
/// - ``save(_:)``
/// - ``saveAll(_:)``
///
/// ### Fetching Data
/// - ``fetch(id:)``
/// - ``fetchAll()``
/// - ``fetch(matching:)``
///
/// ### Deleting Data
/// - ``delete(id:)``
/// - ``deleteAll()``
///
/// ### Transactions
/// - ``performTransaction(_:)``
///
/// ## Example
/// ```swift
/// actor MyStorage: StorageProvider {
///     typealias Entity = MyModel
///
///     func save(_ entity: MyModel) async throws {
///         // Implementation
///     }
/// }
/// ```
public protocol StorageProvider<Entity>: Sendable {
    /// The type of entity this storage provider manages.
    associatedtype Entity: Codable & Sendable & Identifiable

    /// Saves or updates an entity in storage.
    ///
    /// If an entity with the same ID exists, it will be updated.
    /// Otherwise, a new entity is created.
    ///
    /// - Parameter entity: The entity to save
    /// - Throws: ``StorageError`` if the operation fails
    func save(_ entity: Entity) async throws

    /// Saves multiple entities in a batch operation.
    ///
    /// This method is optimized for bulk operations and should be preferred
    /// when saving multiple entities.
    ///
    /// - Parameter entities: Array of entities to save
    /// - Throws: ``StorageError`` if any save operation fails
    func saveAll(_ entities: [Entity]) async throws

    /// Fetches an entity by its unique identifier.
    ///
    /// - Parameter id: The unique identifier of the entity
    /// - Returns: The entity if found, `nil` otherwise
    /// - Throws: ``StorageError`` if the fetch operation fails
    func fetch(id: Entity.ID) async throws -> Entity?

    /// Fetches all entities from storage.
    ///
    /// - Returns: Array of all stored entities
    /// - Throws: ``StorageError`` if the fetch operation fails
    func fetchAll() async throws -> [Entity]

    /// Fetches entities matching a predicate.
    ///
    /// - Parameter predicate: A predicate to filter entities
    /// - Returns: Array of entities matching the predicate
    /// - Throws: ``StorageError`` if the fetch operation fails
    func fetch(matching predicate: Predicate<Entity>) async throws -> [Entity]

    /// Deletes an entity by its unique identifier.
    ///
    /// - Parameter id: The unique identifier of the entity to delete
    /// - Throws: ``StorageError`` if the delete operation fails
    func delete(id: Entity.ID) async throws

    /// Deletes all entities from storage.
    ///
    /// - Warning: This operation cannot be undone
    /// - Throws: ``StorageError`` if the delete operation fails
    func deleteAll() async throws

    /// Executes multiple operations within a transaction.
    ///
    /// If any operation within the transaction fails, all changes are rolled back.
    ///
    /// - Parameter block: A closure containing the operations to execute
    /// - Returns: The result of the transaction block
    /// - Throws: ``StorageError`` if the transaction fails
    func performTransaction<T: Sendable>(_ block: @Sendable () async throws -> T) async throws -> T
}
