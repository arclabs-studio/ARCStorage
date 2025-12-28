# Testing

Learn how to test code that uses ARCStorage.

## Overview

ARCStorage provides comprehensive testing utilities that make it easy to write fast, isolated unit tests.

## Testing Utilities

### MockRepository

Full-featured mock with call tracking:

```swift
import Testing
@testable import ARCStorage

@Test
func loadRestaurants_withMockData_returnsRestaurants() async throws {
    // Arrange
    let mockRepo = MockRepository<Restaurant>()
    mockRepo.mockEntities = [.fixture1, .fixture2]

    let viewModel = RestaurantsViewModel(repository: mockRepo)

    // Act
    await viewModel.loadRestaurants()

    // Assert
    #expect(viewModel.restaurants.count == 2)
    #expect(mockRepo.fetchAllCalled == true)
}
```

### MockStorageProvider

Lower-level mock for storage provider testing:

```swift
let mockStorage = MockStorageProvider<Restaurant>()
mockStorage.mockEntities = [.fixture1]

let entity = try await mockStorage.fetch(id: fixture1.id)
#expect(entity != nil)
```

### InMemoryRepository

Fast, isolated storage for integration tests:

```swift
@Test
func fullCRUDFlow_completesSuccessfully() async throws {
    let repository = InMemoryRepository<Restaurant>()

    // Create
    try await repository.save(.fixture1)

    // Read
    let fetched = try await repository.fetch(id: fixture1.id)
    #expect(fetched != nil)

    // Delete
    try await repository.delete(id: fixture1.id)
    let deleted = try await repository.fetch(id: fixture1.id)
    #expect(deleted == nil)
}
```

## Test Fixtures

ARCStorage includes test fixtures for common scenarios:

```swift
// Use predefined fixtures
let model1 = TestModel.fixture1
let model2 = TestModel.fixture2
let allModels = TestModel.allFixtures
```

## Testing ViewModels

```swift
@Suite("RestaurantsViewModel Tests")
@MainActor
struct RestaurantsViewModelTests {

    @Test("Initial state is empty")
    func initialState_isEmpty() {
        let mockRepo = MockRepository<Restaurant>()
        let viewModel = RestaurantsViewModel(repository: mockRepo)

        #expect(viewModel.restaurants.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test("Load restaurants updates state")
    func loadRestaurants_updatesState() async {
        let mockRepo = MockRepository<Restaurant>()
        mockRepo.mockEntities = [.fixture1, .fixture2]

        let viewModel = RestaurantsViewModel(repository: mockRepo)
        await viewModel.loadRestaurants()

        #expect(viewModel.restaurants.count == 2)
    }

    @Test("Load restaurants with error shows error")
    func loadRestaurants_withError_showsError() async {
        let mockRepo = MockRepository<Restaurant>()
        mockRepo.shouldThrowError = true

        let viewModel = RestaurantsViewModel(repository: mockRepo)
        await viewModel.loadRestaurants()

        #expect(viewModel.errorMessage != nil)
    }
}
```

## Testing Cache Behavior

```swift
@Test
func cache_invalidation_fetchesFreshData() async throws {
    let repository = InMemoryRepository<Restaurant>(cachePolicy: .default)

    try await repository.save(.fixture1)
    _ = try await repository.fetch(id: fixture1.id)  // Populate cache

    await repository.invalidateCache()

    // Should fetch from storage, not cache
    let fetched = try await repository.fetch(id: fixture1.id)
    #expect(fetched != nil)
}
```

## Best Practices

1. **Use MockRepository for unit tests** - Fast, predictable, tracks calls
2. **Use InMemoryRepository for integration tests** - Real behavior, no persistence
3. **Never use real storage in tests** - Tests should be isolated
4. **Test error cases** - Verify error handling works correctly
5. **Test concurrency** - Use TaskGroup to test concurrent operations
