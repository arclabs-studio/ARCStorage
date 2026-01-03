import Foundation

/// Mock storage provider for testing.
///
/// Provides a configurable storage implementation that can simulate
/// errors and track method calls for testing purposes.
///
/// ## Example
/// ```swift
/// let mock = MockStorageProvider<Restaurant>()
/// mock.mockEntities = [restaurant1, restaurant2]
/// mock.shouldThrowError = .saveFailed(underlying: NSError())
///
/// // Test error handling
/// do {
///     try await mock.save(restaurant3)
///     XCTFail("Should have thrown")
/// } catch {
///     // Success
/// }
/// ```
public actor MockStorageProvider<T: Codable & Sendable & Identifiable>: StorageProvider
where T.ID: Sendable & Hashable {
    public typealias Entity = T

    /// Entities to return from fetch operations.
    public var mockEntities: [T] = []

    /// Error to throw from operations.
    public var shouldThrowError: StorageError?

    /// Number of times save was called.
    public var saveCallCount = 0

    /// Number of times saveAll was called.
    public var saveAllCallCount = 0

    /// Number of times fetch was called.
    public var fetchCallCount = 0

    /// Number of times fetchAll was called.
    public var fetchAllCallCount = 0

    /// Number of times delete was called.
    public var deleteCallCount = 0

    /// Number of times deleteAll was called.
    public var deleteAllCallCount = 0

    /// Number of times performTransaction was called.
    public var transactionCallCount = 0

    /// Last entity passed to save.
    public var lastSavedEntity: T?

    /// Last ID passed to delete.
    public var lastDeletedID: T.ID?

    /// Creates a new mock storage provider.
    public init() {}

    public func save(_ entity: T) async throws {
        saveCallCount += 1
        lastSavedEntity = entity

        if let error = shouldThrowError {
            throw error
        }

        // Add to mock entities if not already present
        if let index = mockEntities.firstIndex(where: { $0.id == entity.id }) {
            mockEntities[index] = entity
        } else {
            mockEntities.append(entity)
        }
    }

    public func saveAll(_ entities: [T]) async throws {
        saveAllCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        for entity in entities {
            try await save(entity)
        }
    }

    public func fetch(id: T.ID) async throws -> T? {
        fetchCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return mockEntities.first { $0.id == id }
    }

    public func fetchAll() async throws -> [T] {
        fetchAllCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return mockEntities
    }

    public func fetch(matching predicate: Predicate<T>) async throws -> [T] {
        fetchCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return try mockEntities.filter { entity in
            try predicate.evaluate(entity)
        }
    }

    public func delete(id: T.ID) async throws {
        deleteCallCount += 1
        lastDeletedID = id

        if let error = shouldThrowError {
            throw error
        }

        mockEntities.removeAll { $0.id == id }
    }

    public func deleteAll() async throws {
        deleteAllCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        mockEntities.removeAll()
    }

    public func performTransaction<Result: Sendable>(
        _ block: @Sendable () async throws -> Result
    ) async throws -> Result {
        transactionCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return try await block()
    }

    /// Resets all call counts and clears mock data.
    public func reset() {
        mockEntities.removeAll()
        shouldThrowError = nil
        saveCallCount = 0
        saveAllCallCount = 0
        fetchCallCount = 0
        fetchAllCallCount = 0
        deleteCallCount = 0
        deleteAllCallCount = 0
        transactionCallCount = 0
        lastSavedEntity = nil
        lastDeletedID = nil
    }
}
