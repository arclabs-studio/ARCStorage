# Repository Pattern

Understanding and implementing the repository pattern with ARCStorage.

## Overview

The repository pattern creates an abstraction layer between your domain logic and data persistence. ARCStorage implements this pattern to provide clean, testable code that's independent of storage implementation details.

## Why Repository Pattern?

### Problems it Solves

1. **Tight Coupling**: Direct use of `@Query` couples views to SwiftData
2. **Testing Difficulty**: Hard to test views that depend on persistence
3. **Inflexibility**: Changing storage backends requires rewriting code
4. **Business Logic**: Storage operations mixed with business rules

### Benefits

- ✅ **Testability**: Easy to mock for unit tests
- ✅ **Flexibility**: Swap storage backends without changing domain code
- ✅ **Separation of Concerns**: Clear boundaries between layers
- ✅ **Reusability**: Share repositories across features

## Architecture Layers

```
┌──────────────────────────────────────┐
│         Presentation Layer           │
│      (Views, ViewModels)             │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│          Domain Layer                │
│        (Repositories)                │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│     ARCStorage Layer                 │
│  (StorageProvider, Repository)       │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│       Storage Backend                │
│    (SwiftData, UserDefaults)         │
└──────────────────────────────────────┘
```

## Implementing a Repository

### 1. Define Repository Protocol

```swift
protocol RestaurantRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Restaurant]
    func fetch(id: UUID) async throws -> Restaurant?
    func fetchFavorites() async throws -> [Restaurant]
    func fetchNearby(location: Location) async throws -> [Restaurant]
    func save(_ restaurant: Restaurant) async throws
    func delete(id: UUID) async throws
}
```

### 2. Implement with ARCStorage

```swift
actor RestaurantRepository: RestaurantRepositoryProtocol {
    private let storage: any Repository<Restaurant>

    init(storage: any Repository<Restaurant>) {
        self.storage = storage
    }

    func fetchAll() async throws -> [Restaurant] {
        try await storage.fetchAll()
    }

    func fetch(id: UUID) async throws -> Restaurant? {
        try await storage.fetch(id: id)
    }

    func fetchFavorites() async throws -> [Restaurant] {
        let predicate = #Predicate<Restaurant> { $0.isFavorite == true }
        return try await storage.fetch(matching: predicate)
    }

    func fetchNearby(location: Location) async throws -> [Restaurant] {
        let predicate = #Predicate<Restaurant> { restaurant in
            restaurant.distance(from: location) < 5.0
        }
        return try await storage.fetch(matching: predicate)
    }

    func save(_ restaurant: Restaurant) async throws {
        try await storage.save(restaurant)
    }

    func delete(id: UUID) async throws {
        try await storage.delete(id: id)
    }
}
```

### 3. Add Business Logic

```swift
extension RestaurantRepository {
    /// Validates and saves a restaurant
    func saveValidated(_ restaurant: Restaurant) async throws {
        // Business rule: Name must not be empty
        guard !restaurant.name.isEmpty else {
            throw ValidationError.emptyName
        }

        // Business rule: Rating must be between 0-5
        guard (0...5).contains(restaurant.rating) else {
            throw ValidationError.invalidRating
        }

        try await save(restaurant)
    }

    /// Archives a restaurant instead of deleting
    func archive(id: UUID) async throws {
        guard var restaurant = try await fetch(id: id) else {
            throw StorageError.notFound(id: id)
        }

        restaurant.isArchived = true
        try await save(restaurant)
    }
}

enum ValidationError: Error {
    case emptyName
    case invalidRating
}
```

## Using Repositories in ViewModels

### ✅ Good: Decoupled ViewModel

```swift
@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var favorites: [Restaurant] = []

    private let repository: any RestaurantRepositoryProtocol

    init(repository: any RestaurantRepositoryProtocol) {
        self.repository = repository
    }

    func loadRestaurants() async {
        do {
            restaurants = try await repository.fetchAll()
        } catch {
            // Handle error
        }
    }

    func loadFavorites() async {
        do {
            favorites = try await repository.fetchFavorites()
        } catch {
            // Handle error
        }
    }

    func toggleFavorite(_ restaurant: Restaurant) async {
        var updated = restaurant
        updated.isFavorite.toggle()

        do {
            try await repository.save(updated)
            await loadRestaurants()
        } catch {
            // Handle error
        }
    }
}
```

### ❌ Bad: Coupled to SwiftData

```swift
// DON'T DO THIS
struct RestaurantsView: View {
    @Query private var restaurants: [Restaurant]  // Tightly coupled!

    var body: some View {
        List(restaurants) { restaurant in
            Text(restaurant.name)
        }
    }
}
```

## Testing with Repositories

### Unit Testing with Mocks

```swift
final class RestaurantsViewModelTests: XCTestCase {
    func testLoadRestaurants() async throws {
        // Given
        let mockRepo = MockRestaurantRepository()
        mockRepo.mockRestaurants = [.fixture1, .fixture2]
        let viewModel = RestaurantsViewModel(repository: mockRepo)

        // When
        await viewModel.loadRestaurants()

        // Then
        XCTAssertEqual(viewModel.restaurants.count, 2)
        XCTAssertEqual(mockRepo.fetchAllCallCount, 1)
    }

    func testToggleFavorite() async throws {
        // Given
        let mockRepo = MockRestaurantRepository()
        let restaurant = Restaurant.fixture1
        mockRepo.mockRestaurants = [restaurant]
        let viewModel = RestaurantsViewModel(repository: mockRepo)

        // When
        await viewModel.toggleFavorite(restaurant)

        // Then
        XCTAssertEqual(mockRepo.saveCallCount, 1)
        XCTAssertTrue(mockRepo.lastSavedRestaurant?.isFavorite == true)
    }
}

actor MockRestaurantRepository: RestaurantRepositoryProtocol {
    var mockRestaurants: [Restaurant] = []
    var fetchAllCallCount = 0
    var saveCallCount = 0
    var lastSavedRestaurant: Restaurant?

    func fetchAll() async throws -> [Restaurant] {
        fetchAllCallCount += 1
        return mockRestaurants
    }

    func save(_ restaurant: Restaurant) async throws {
        saveCallCount += 1
        lastSavedRestaurant = restaurant
    }

    // ... other methods
}
```

### Integration Testing

```swift
final class RestaurantRepositoryIntegrationTests: XCTestCase {
    var repository: RestaurantRepository!
    var storage: InMemoryRepository<Restaurant>!

    override func setUp() async throws {
        storage = InMemoryRepository<Restaurant>()
        repository = RestaurantRepository(storage: storage)
    }

    func testFetchNearby() async throws {
        // Given
        let location = Location(latitude: 37.7749, longitude: -122.4194)
        let nearRestaurant = Restaurant(
            id: UUID(),
            name: "Nearby",
            location: location
        )
        let farRestaurant = Restaurant(
            id: UUID(),
            name: "Far Away",
            location: Location(latitude: 40.7128, longitude: -74.0060)
        )

        try await repository.save(nearRestaurant)
        try await repository.save(farRestaurant)

        // When
        let results = try await repository.fetchNearby(location: location)

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Nearby")
    }
}
```

## Advanced Patterns

### Use Case Objects

For complex operations, create dedicated use cases:

```swift
actor ImportRestaurantsUseCase {
    private let repository: any RestaurantRepositoryProtocol
    private let apiClient: APIClient

    func execute() async throws {
        let restaurants = try await apiClient.fetchRestaurants()

        for restaurant in restaurants {
            try await repository.saveValidated(restaurant)
        }
    }
}
```

### Composite Repositories

Combine multiple storage backends:

```swift
actor CompositeRestaurantRepository: RestaurantRepositoryProtocol {
    private let localStorage: any Repository<Restaurant>
    private let remoteStorage: any Repository<Restaurant>

    func fetchAll() async throws -> [Restaurant] {
        // Try local first
        let local = try? await localStorage.fetchAll()
        if let local, !local.isEmpty {
            return local
        }

        // Fall back to remote
        let remote = try await remoteStorage.fetchAll()

        // Cache locally
        for restaurant in remote {
            try? await localStorage.save(restaurant)
        }

        return remote
    }
}
```

## Best Practices

1. **Keep repositories focused**
   - One repository per entity type
   - Clear, single responsibility

2. **Use protocols for testability**
   - Define repository protocols
   - Inject dependencies

3. **Add business logic in repositories**
   - Validation
   - Transformations
   - Domain rules

4. **Don't leak storage details**
   - Return domain models, not storage types
   - Hide implementation details

5. **Use actors for thread safety**
   - Repository operations are often async
   - Actors prevent data races

## See Also

- ``Repository``
- ``MockRepository``
- <doc:Testing>
- <doc:GettingStarted>
