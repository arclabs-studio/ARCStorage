# 🗄️ ARCStorage

Protocol-based storage abstraction for iOS apps supporting SwiftData, UserDefaults, Keychain, and testing.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)
![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)

---

## ✨ Features

- 🏗️ **Clean Architecture**: Repository Pattern with protocol-first design
- 🔄 **SwiftData Integration**: First-class support for SwiftData (iOS 17+)
- 🧪 **Fully Testable**: Mocks and in-memory storage for unit tests
- 🔒 **Secure Storage**: Keychain integration for sensitive data
- ⚡ **Built-in Caching**: LRU cache with configurable TTL
- 🔐 **Thread-Safe**: Swift 6 concurrency (actors, Sendable)
- 📱 **Zero SwiftUI Coupling**: Domain layer independent of views
- ☁️ **CloudKit Ready**: Optional iCloud synchronization

## 🎯 Why ARCStorage?

### The Problem

Using SwiftData's `@Query` directly in SwiftUI views creates tight coupling:

```swift
// ❌ Tightly coupled to SwiftData
struct RestaurantsView: View {
    @Query private var restaurants: [Restaurant]  // Can't test this!

    var body: some View {
        List(restaurants) { restaurant in
            Text(restaurant.name)
        }
    }
}
```

**Issues:**
- ❌ Impossible to unit test
- ❌ Locked into SwiftData
- ❌ Business logic mixed with views
- ❌ Hard to mock for previews

### The Solution

ARCStorage provides repositories that abstract storage:

```swift
// ✅ Decoupled and testable
@MainActor
class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    private let repository: any Repository<Restaurant>

    init(repository: any Repository<Restaurant>) {
        self.repository = repository
    }

    func loadRestaurants() async {
        restaurants = try await repository.fetchAll()
    }
}
```

**Benefits:**
- ✅ Fully testable with mocks
- ✅ Swap storage backends easily
- ✅ Clean separation of concerns
- ✅ Easy to preview and test

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCStorage.git", from: "1.0.0")
]
```

Or add via Xcode: `File → Add Package Dependencies`

## 🚀 Quick Start

### 1. Define Your Model

```swift
import SwiftData

@Model
final class Restaurant: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var cuisine: String
    var rating: Double

    init(id: UUID = UUID(), name: String, cuisine: String, rating: Double) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.rating = rating
    }
}
```

### 2. Configure in Your App

```swift
import SwiftUI
import SwiftData
import ARCStorage

@main
struct MyApp: App {
    let container: ModelContainer

    init() {
        let config = SwiftDataConfiguration(
            schema: Schema([Restaurant.self]),
            isCloudKitEnabled: true
        )
        container = try! config.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

### 3. Create Repository

```swift
actor RestaurantRepository {
    private let repository: SwiftDataRepository<Restaurant>

    init(modelContainer: ModelContainer) {
        let storage = SwiftDataStorage<Restaurant>(modelContainer: modelContainer)
        self.repository = SwiftDataRepository(storage: storage)
    }

    func fetchAll() async throws -> [Restaurant] {
        try await repository.fetchAll()
    }

    func save(_ restaurant: Restaurant) async throws {
        try await repository.save(restaurant)
    }
}
```

### 4. Use in ViewModel

```swift
@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    private let repository: RestaurantRepository

    init(repository: RestaurantRepository) {
        self.repository = repository
    }

    func loadRestaurants() async {
        do {
            restaurants = try await repository.fetchAll()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## 📚 Storage Backends

### SwiftData (Recommended)

For persistent storage with CloudKit sync:

```swift
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
let repository = SwiftDataRepository(storage: storage, cachePolicy: .default)
```

### InMemory (Testing)

Fast, isolated storage for tests:

```swift
let storage = InMemoryStorage<Restaurant>()
let repository = InMemoryRepository<Restaurant>()
```

### UserDefaults (Simple Data)

For preferences and settings:

```swift
let storage = UserDefaultsStorage<Settings>()
let repository = UserDefaultsRepository<Settings>()
```

### Keychain (Secure Data)

For tokens and credentials:

```swift
let storage = KeychainStorage<AuthToken>(service: "com.myapp.auth")
let repository = KeychainRepository<AuthToken>(service: "com.myapp.auth")
```

## 🧪 Testing

ARCStorage makes testing easy with mocks:

```swift
func testLoadRestaurants() async throws {
    // Given
    let mockRepo = MockRepository<Restaurant>()
    mockRepo.mockEntities = [.fixture1, .fixture2]

    let viewModel = RestaurantsViewModel(repository: mockRepo)

    // When
    await viewModel.loadRestaurants()

    // Then
    XCTAssertEqual(viewModel.restaurants.count, 2)
}
```

## 🔍 Advanced Features

### Caching

Control cache behavior with policies:

```swift
// Aggressive caching (1 hour TTL, 500 items)
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .aggressive
)

// No caching (always fresh)
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .noCache
)

// Custom policy
let customPolicy = CachePolicy(
    ttl: 600,      // 10 minutes
    maxSize: 200,
    strategy: .lru
)
```

### Queries with Predicates

```swift
// Find high-rated Italian restaurants
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}
let results = try await repository.fetch(matching: predicate)
```

### CloudKit Sync

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    isCloudKitEnabled: true
)

let cloudConfig = CloudKitConfiguration(
    containerIdentifier: "iCloud.com.myapp.container",
    conflictResolution: .mostRecentWins
)

// Monitor sync status
let monitor = CloudKitSyncMonitor()
monitor.startMonitoring()
```

### Data Migration

```swift
let migration = MigrationPlan(
    sourceVersion: "1.0",
    destinationVersion: "2.0"
) { context in
    // Transform data during migration
}

let manager = MigrationManager()
await manager.addPlan(migration)
try await manager.migrate(from: "1.0", to: "2.0")
```

## 📖 Documentation

Full documentation available at [Documentation](https://arclabs-studio.github.io/ARCStorage/documentation/arcstorage/)

Topics:
- [Getting Started](https://arclabs-studio.github.io/ARCStorage/documentation/arcstorage/gettingstarted)
- [SwiftData Integration](https://arclabs-studio.github.io/ARCStorage/documentation/arcstorage/swiftdataintegration)
- [Repository Pattern](https://arclabs-studio.github.io/ARCStorage/documentation/arcstorage/repositorypattern)
- [Testing Guide](https://arclabs-studio.github.io/ARCStorage/documentation/arcstorage/testing)

## 🏗️ Architecture

```
┌──────────────────────────────────────┐
│         Presentation Layer           │
│      (Views, ViewModels)             │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│          Domain Layer                │
│    (Domain-specific Repositories)    │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│       ARCStorage Layer               │
│  (Repository, StorageProvider)       │
└──────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────┐
│       Storage Backend                │
│  (SwiftData, UserDefaults, etc.)     │
└──────────────────────────────────────┘
```

## 🔧 Requirements

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+
- Swift 6.0+
- Xcode 16.0+

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

## 📄 License

ARCStorage is available under the MIT license. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with Swift 6 strict concurrency
- Designed for Clean Architecture
- Inspired by Domain-Driven Design principles

## 📞 Support

- [Documentation](https://arclabs-studio.github.io/ARCStorage)
- [GitHub Issues](https://github.com/arclabs-studio/ARCStorage/issues)
- [Discussions](https://github.com/arclabs-studio/ARCStorage/discussions)

---

Made with ❤️ by ARC Labs Studio
