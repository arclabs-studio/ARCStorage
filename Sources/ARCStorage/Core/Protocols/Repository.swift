import Foundation

/// High-level repository protocol for domain layer.
///
/// `Repository` provides a business-logic-oriented interface on top of ``StorageProvider``.
/// It adds caching, validation, and domain-specific operations.
///
/// ## Topics
/// ### Data Operations
/// - ``save(_:)``
/// - ``fetchAll()``
/// - ``fetch(id:)``
/// - ``delete(id:)``
///
/// ### Cache Management
/// - ``invalidateCache()``
///
/// ## Example
/// ```swift
/// actor RestaurantRepository: Repository {
///     typealias Entity = Restaurant
///
///     private let storage: any StorageProvider<Restaurant>
///
///     func fetchNearby(location: Location) async throws -> [Restaurant] {
///         let predicate = #Predicate<Restaurant> { restaurant in
///             restaurant.distance(from: location) < 5.0
///         }
///         return try await storage.fetch(matching: predicate)
///     }
/// }
/// ```
public protocol Repository<Entity>: Sendable {
    /// The type of entity this repository manages.
    associatedtype Entity: Codable & Sendable & Identifiable

    /// Saves or updates an entity.
    ///
    /// - Parameter entity: The entity to save
    /// - Throws: ``StorageError`` if the operation fails
    func save(_ entity: Entity) async throws

    /// Fetches all entities.
    ///
    /// - Returns: Array of all entities
    /// - Throws: ``StorageError`` if the operation fails
    func fetchAll() async throws -> [Entity]

    /// Fetches an entity by its identifier.
    ///
    /// - Parameter id: The unique identifier
    /// - Returns: The entity if found, `nil` otherwise
    /// - Throws: ``StorageError`` if the operation fails
    func fetch(id: Entity.ID) async throws -> Entity?

    /// Deletes an entity by its identifier.
    ///
    /// - Parameter id: The unique identifier
    /// - Throws: ``StorageError`` if the operation fails
    func delete(id: Entity.ID) async throws

    /// Invalidates the cache for this repository.
    ///
    /// After calling this method, subsequent fetch operations will retrieve
    /// fresh data from the underlying storage.
    func invalidateCache() async
}
