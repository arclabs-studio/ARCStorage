import Foundation

/// Mock repository for testing ViewModels and use cases.
///
/// Provides a simple, configurable repository implementation that
/// tracks method calls and can simulate various scenarios.
///
/// ## Example
/// ```swift
/// let mockRepo = MockRepository<Restaurant>()
/// mockRepo.mockEntities = [.fixture1, .fixture2]
///
/// let viewModel = RestaurantsViewModel(repository: mockRepo)
/// await viewModel.loadRestaurants()
///
/// XCTAssertEqual(await mockRepo.fetchAllCallCount, 1)
/// ```
public actor MockRepository<T: Codable & Sendable & Identifiable>: Repository where T.ID: Sendable & Hashable {
    public typealias Entity = T

    /// Entities to return from fetch operations.
    public var mockEntities: [T] = []

    /// Error to throw from operations.
    public var shouldThrowError: StorageError?

    /// Number of times save was called.
    public var saveCallCount = 0

    /// Number of times fetchAll was called.
    public var fetchAllCallCount = 0

    /// Number of times fetch(id:) was called.
    public var fetchCallCount = 0

    /// Number of times delete was called.
    public var deleteCallCount = 0

    /// Number of times invalidateCache was called.
    public var invalidateCacheCallCount = 0

    /// Last entity passed to save.
    public var lastSavedEntity: T?

    /// Last ID passed to fetch or delete.
    public var lastAccessedID: T.ID?

    /// Creates a new mock repository.
    public init() {}

    public func save(_ entity: T) async throws {
        saveCallCount += 1
        lastSavedEntity = entity

        if let error = shouldThrowError {
            throw error
        }

        // Update or add to mock entities
        if let index = mockEntities.firstIndex(where: { $0.id == entity.id }) {
            mockEntities[index] = entity
        } else {
            mockEntities.append(entity)
        }
    }

    public func fetchAll() async throws -> [T] {
        fetchAllCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return mockEntities
    }

    public func fetch(id: T.ID) async throws -> T? {
        fetchCallCount += 1
        lastAccessedID = id

        if let error = shouldThrowError {
            throw error
        }

        return mockEntities.first { $0.id == id }
    }

    public func delete(id: T.ID) async throws {
        deleteCallCount += 1
        lastAccessedID = id

        if let error = shouldThrowError {
            throw error
        }

        mockEntities.removeAll { $0.id == id }
    }

    public func invalidateCache() async {
        invalidateCacheCallCount += 1
    }

    /// Resets all call counts and clears mock data.
    public func reset() {
        mockEntities.removeAll()
        shouldThrowError = nil
        saveCallCount = 0
        fetchAllCallCount = 0
        fetchCallCount = 0
        deleteCallCount = 0
        invalidateCacheCallCount = 0
        lastSavedEntity = nil
        lastAccessedID = nil
    }
}
