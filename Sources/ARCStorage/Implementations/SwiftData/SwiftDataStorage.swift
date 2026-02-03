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
        modelContext = modelContainer.mainContext
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

    /// Fetches an entity by its identifier.
    ///
    /// This method is optimized for performance:
    /// 1. First checks the registered objects cache (O(1) lookup)
    /// 2. Falls back to a full fetch with early exit if not cached
    ///
    /// - Note: For best performance, add `@Attribute(.unique)` to your model's `id` property.
    ///   This creates a database index that SwiftData can use for faster lookups.
    ///
    /// - Parameter id: The unique identifier of the entity to fetch
    /// - Returns: The entity if found, `nil` otherwise
    /// - Throws: ``StorageError`` if the fetch operation fails
    public func fetch(id: T.ID) throws -> T? {
        // 1. Check registered objects cache first (O(1) lookup)
        if let cached = registeredObjects[id] {
            // Verify it's still valid in the context
            if !cached.isDeleted {
                return cached
            }
            registeredObjects.removeValue(forKey: id)
        }

        // 2. Fetch all and find with early exit
        //    Generic T.ID prevents direct predicate usage (#Predicate requires concrete types).
        //    SwiftData optimizes internally when @Attribute(.unique) is used on the id property.
        let descriptor = FetchDescriptor<T>()
        let results = try modelContext.fetch(descriptor)

        if let entity = results.first(where: { $0.id == id }) {
            registeredObjects[id] = entity
            return entity
        }

        return nil
    }

    /// Fetches all entities.
    ///
    /// - Returns: Array of all entities
    /// - Throws: ``StorageError`` if the fetch operation fails
    public func fetchAll() throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all entities with relationship prefetching.
    ///
    /// Use this method to avoid N+1 query problems when you need to access
    /// relationships on the fetched entities.
    ///
    /// - Parameter relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of all entities with prefetched relationships
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// // Prefetch reviews when fetching restaurants
    /// let restaurants = try storage.fetchAll(
    ///     prefetching: [\Restaurant.reviews]
    /// )
    /// // Accessing reviews won't trigger additional queries
    /// for restaurant in restaurants {
    ///     print(restaurant.reviews?.count ?? 0)
    /// }
    /// ```
    public func fetchAll(
        prefetching relationshipKeyPaths: [PartialKeyPath<T>]
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        descriptor.relationshipKeyPathsForPrefetching = relationshipKeyPaths
        return try modelContext.fetch(descriptor)
    }

    /// Fetches entities matching a predicate.
    ///
    /// - Parameter predicate: The predicate to filter entities
    /// - Returns: Array of matching entities
    /// - Throws: ``StorageError`` if the fetch operation fails
    public func fetch(matching predicate: Predicate<T>) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    /// Fetches entities matching a predicate with relationship prefetching.
    ///
    /// Use this method to avoid N+1 query problems when filtering entities
    /// and accessing their relationships.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter entities
    ///   - relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of matching entities with prefetched relationships
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// // Fetch high-rated restaurants with their reviews prefetched
    /// let predicate = #Predicate<Restaurant> { $0.rating >= 4.0 }
    /// let topRestaurants = try storage.fetch(
    ///     matching: predicate,
    ///     prefetching: [\Restaurant.reviews, \Restaurant.owner]
    /// )
    /// ```
    public func fetch(
        matching predicate: Predicate<T>,
        prefetching relationshipKeyPaths: [PartialKeyPath<T>]
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.relationshipKeyPathsForPrefetching = relationshipKeyPaths
        return try modelContext.fetch(descriptor)
    }

    /// Fetches entities with full configuration options.
    ///
    /// This method provides complete control over the fetch operation, including
    /// filtering, sorting, pagination, and relationship prefetching.
    ///
    /// - Parameters:
    ///   - predicate: Optional predicate to filter entities
    ///   - sortDescriptors: Sort descriptors for ordering results
    ///   - fetchLimit: Maximum number of entities to fetch
    ///   - fetchOffset: Number of entities to skip (for pagination)
    ///   - relationshipKeyPaths: Key paths to relationships that should be prefetched
    /// - Returns: Array of entities matching the criteria
    /// - Throws: ``StorageError`` if the fetch operation fails
    ///
    /// ## Example
    /// ```swift
    /// // Fetch paginated results with sorting and prefetching
    /// let predicate = #Predicate<Restaurant> { $0.isOpen }
    /// let restaurants = try storage.fetch(
    ///     matching: predicate,
    ///     sortedBy: [Foundation.SortDescriptor(\.rating, order: .reverse)],
    ///     limit: 20,
    ///     offset: 0,
    ///     prefetching: [\Restaurant.reviews]
    /// )
    /// ```
    public func fetch(
        matching predicate: Predicate<T>? = nil,
        sortedBy sortDescriptors: [Foundation.SortDescriptor<T>] = [],
        limit fetchLimit: Int? = nil,
        offset fetchOffset: Int? = nil,
        prefetching relationshipKeyPaths: [PartialKeyPath<T>] = []
    ) throws -> [T] {
        var descriptor = if let predicate {
            FetchDescriptor<T>(predicate: predicate, sortBy: sortDescriptors)
        } else {
            FetchDescriptor<T>(sortBy: sortDescriptors)
        }

        if let fetchLimit {
            descriptor.fetchLimit = fetchLimit
        }
        if let fetchOffset {
            descriptor.fetchOffset = fetchOffset
        }
        if !relationshipKeyPaths.isEmpty {
            descriptor.relationshipKeyPathsForPrefetching = relationshipKeyPaths
        }

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
