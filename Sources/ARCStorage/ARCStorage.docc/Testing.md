# Testing

Comprehensive testing strategies for ARCStorage-based applications.

## Overview

ARCStorage is designed for testability. This guide covers unit testing, integration testing, and performance testing strategies.

## Testing Pyramid

```
        ┌─────────────┐
        │     E2E     │  Few, slow
        └─────────────┘
      ┌─────────────────┐
      │  Integration    │  Some, moderate
      └─────────────────┘
    ┌───────────────────────┐
    │    Unit Tests         │  Many, fast
    └───────────────────────┘
```

## Unit Testing

### Testing ViewModels with Mocks

```swift
import XCTest
@testable import MyApp
import ARCStorage

final class RestaurantsViewModelTests: XCTestCase {
    var viewModel: RestaurantsViewModel!
    var mockRepository: MockRepository<Restaurant>!

    override func setUp() async throws {
        mockRepository = MockRepository<Restaurant>()
        viewModel = RestaurantsViewModel(repository: mockRepository)
    }

    func testLoadRestaurants_Success() async throws {
        // Given
        await mockRepository.setMockEntities([
            .fixture1,
            .fixture2,
            .fixture3
        ])

        // When
        await viewModel.loadRestaurants()

        // Then
        XCTAssertEqual(viewModel.restaurants.count, 3)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)

        let callCount = await mockRepository.fetchAllCallCount
        XCTAssertEqual(callCount, 1)
    }

    func testLoadRestaurants_Error() async throws {
        // Given
        let expectedError = StorageError.fetchFailed(
            underlying: NSError(domain: "test", code: 1)
        )
        await mockRepository.setShouldThrowError(expectedError)

        // When
        await viewModel.loadRestaurants()

        // Then
        XCTAssertTrue(viewModel.restaurants.isEmpty)
        XCTAssertNotNil(viewModel.error)
    }

    func testAddRestaurant() async throws {
        // Given
        let newRestaurant = Restaurant(
            id: UUID(),
            name: "New Place",
            rating: 4.5
        )

        // When
        await viewModel.addRestaurant(newRestaurant)

        // Then
        let saveCount = await mockRepository.saveCallCount
        let lastSaved = await mockRepository.lastSavedEntity

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(lastSaved?.id, newRestaurant.id)
    }

    func testDeleteRestaurant() async throws {
        // Given
        await mockRepository.setMockEntities([.fixture1])
        await viewModel.loadRestaurants()

        // When
        await viewModel.deleteRestaurant(id: Restaurant.fixture1.id)

        // Then
        let deleteCount = await mockRepository.deleteCallCount
        XCTAssertEqual(deleteCount, 1)
    }
}
```

### Creating Test Fixtures

```swift
extension Restaurant {
    static var fixture1: Restaurant {
        Restaurant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test Restaurant 1",
            cuisine: "Italian",
            rating: 4.5
        )
    }

    static var fixture2: Restaurant {
        Restaurant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Test Restaurant 2",
            cuisine: "Japanese",
            rating: 4.0
        )
    }

    static var allFixtures: [Restaurant] {
        [fixture1, fixture2]
    }
}
```

## Integration Testing

### Testing with InMemoryStorage

```swift
final class RestaurantRepositoryIntegrationTests: XCTestCase {
    var repository: RestaurantRepository!
    var storage: InMemoryRepository<Restaurant>!

    override func setUp() async throws {
        storage = InMemoryRepository<Restaurant>()
        repository = RestaurantRepository(storage: storage)
    }

    func testFullCRUDFlow() async throws {
        let restaurant = Restaurant.fixture1

        // Create
        try await repository.save(restaurant)

        // Read
        let fetched = try await repository.fetch(id: restaurant.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, restaurant.name)

        // Update
        var updated = restaurant
        updated.rating = 5.0
        try await repository.save(updated)

        let fetchedAgain = try await repository.fetch(id: restaurant.id)
        XCTAssertEqual(fetchedAgain?.rating, 5.0)

        // Delete
        try await repository.delete(id: restaurant.id)
        let fetchedAfterDelete = try await repository.fetch(id: restaurant.id)
        XCTAssertNil(fetchedAfterDelete)
    }

    func testQueryOperations() async throws {
        // Given
        try await repository.save(
            Restaurant(id: UUID(), name: "Italian 1", cuisine: "Italian", rating: 4.5)
        )
        try await repository.save(
            Restaurant(id: UUID(), name: "Italian 2", cuisine: "Italian", rating: 3.5)
        )
        try await repository.save(
            Restaurant(id: UUID(), name: "Japanese 1", cuisine: "Japanese", rating: 4.0)
        )

        // When
        let italian = try await repository.fetch(
            matching: #Predicate { $0.cuisine == "Italian" }
        )

        let highRated = try await repository.fetch(
            matching: #Predicate { $0.rating >= 4.0 }
        )

        // Then
        XCTAssertEqual(italian.count, 2)
        XCTAssertEqual(highRated.count, 2)
    }

    func testConcurrentOperations() async throws {
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let restaurant = Restaurant(
                        id: UUID(),
                        name: "Restaurant \(i)",
                        cuisine: "Test",
                        rating: Double(i % 5)
                    )
                    try? await self.repository.save(restaurant)
                }
            }
        }

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, iterations)
    }
}
```

### Testing Storage Providers

```swift
final class UserDefaultsStorageTests: XCTestCase {
    var storage: UserDefaultsStorage<SimpleTestModel>!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        // Use unique suite name for isolation
        let suiteName = "test.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        storage = UserDefaultsStorage(
            userDefaults: userDefaults,
            keyPrefix: "test"
        )
    }

    override func tearDown() async throws {
        // Clean up
        if let suiteName = userDefaults.persistentDomainNames().first {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
    }

    func testSaveAndFetch() async throws {
        let model = SimpleTestModel(id: "test1", data: "Test Data")

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        XCTAssertEqual(fetched?.id, model.id)
        XCTAssertEqual(fetched?.data, model.data)
    }
}
```

## Performance Testing

### Measuring Operation Speed

```swift
final class PerformanceTests: XCTestCase {
    func testBatchSavePerformance() async throws {
        let storage = InMemoryStorage<TestModel>()
        let count = 1000

        measure {
            let models = (0..<count).map { i in
                TestModel(id: UUID(), name: "Test \(i)", value: i)
            }

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                try? await storage.saveAll(models)
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    func testCacheHitRate() async throws {
        let cache = CacheManager<UUID, TestModel>(policy: .default)
        let model = TestModel.fixture1

        await cache.set(model, for: model.id)

        var hits = 0
        let iterations = 100

        for _ in 0..<iterations {
            if await cache.get(model.id) != nil {
                hits += 1
            }
        }

        let hitRate = Double(hits) / Double(iterations)
        XCTAssertGreaterThan(hitRate, 0.95) // Expect >95% hit rate
    }
}
```

### Memory Usage Testing

```swift
func testMemoryUsageUnderLoad() async throws {
    let storage = InMemoryStorage<TestModel>()

    // Measure initial memory
    let initialMemory = reportMemory()

    // Add many entities
    let models = (0..<10_000).map { i in
        TestModel(id: UUID(), name: "Test \(i)", value: i)
    }
    try await storage.saveAll(models)

    // Measure final memory
    let finalMemory = reportMemory()

    // Assert reasonable memory usage
    let memoryIncrease = finalMemory - initialMemory
    XCTAssertLessThan(memoryIncrease, 100_000_000) // 100MB limit
}

func reportMemory() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        return info.resident_size
    }
    return 0
}
```

## Testing Best Practices

### 1. Use Fixtures

Create reusable test data:

```swift
enum RestaurantFixtures {
    static let italian = Restaurant(
        id: UUID(uuidString: "...")!,
        name: "La Trattoria",
        cuisine: "Italian",
        rating: 4.5
    )

    static let japanese = Restaurant(
        id: UUID(uuidString: "...")!,
        name: "Sushi Place",
        cuisine: "Japanese",
        rating: 4.0
    )

    static var all: [Restaurant] {
        [italian, japanese]
    }
}
```

### 2. Isolate Tests

Each test should be independent:

```swift
override func setUp() async throws {
    // Create fresh instances
    storage = InMemoryStorage<Restaurant>()
    repository = RestaurantRepository(storage: storage)
}

override func tearDown() async throws {
    // Clean up
    try? await storage.deleteAll()
}
```

### 3. Test Error Paths

Don't just test happy paths:

```swift
func testSaveFailure() async {
    await mockRepository.setShouldThrowError(
        .saveFailed(underlying: NSError(domain: "test", code: 1))
    )

    do {
        try await repository.save(restaurant)
        XCTFail("Should have thrown error")
    } catch {
        // Expected
    }
}
```

### 4. Use XCTest Expectations

For async operations:

```swift
func testAsyncOperation() async throws {
    let expectation = expectation(description: "Operation completes")

    Task {
        try await repository.save(restaurant)
        expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 5.0)
}
```

### 5. Test Concurrency

Ensure thread safety:

```swift
func testConcurrentWrites() async throws {
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                let model = TestModel(id: UUID(), name: "Test \(i)", value: i)
                try? await self.storage.save(model)
            }
        }
    }

    let count = try await storage.fetchAll().count
    XCTAssertEqual(count, 100)
}
```

## Test Organization

```
Tests/
├── Unit/
│   ├── ViewModels/
│   │   └── RestaurantsViewModelTests.swift
│   ├── Repositories/
│   │   └── RestaurantRepositoryTests.swift
│   └── UseCases/
│       └── ImportRestaurantsUseCaseTests.swift
├── Integration/
│   ├── RepositoryIntegrationTests.swift
│   └── StorageIntegrationTests.swift
├── Performance/
│   └── PerformanceTests.swift
└── Fixtures/
    └── RestaurantFixtures.swift
```

## See Also

- ``MockRepository``
- ``MockStorageProvider``
- ``InMemoryStorage``
- ``TestHelpers``
- <doc:RepositoryPattern>
