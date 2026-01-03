# 🗄️ ARCStorage

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20watchOS%2010%20%7C%20tvOS%2017-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)

**Protocol-based storage abstraction for iOS apps supporting SwiftData, UserDefaults, Keychain, and testing.**

Clean Architecture • Repository Pattern • Thread-Safe • Fully Testable

---

## 🎯 Overview

ARCStorage provides a clean, testable architecture for data persistence that completely decouples your domain layer from persistence details. Built with Swift 6 strict concurrency, it offers multiple storage backends with a unified interface.

### The Problem

Using SwiftData's `@Query` directly in SwiftUI views creates tight coupling:

```swift
// ❌ Tightly coupled to SwiftData
struct RestaurantsView: View {
    @Query private var restaurants: [Restaurant]  // Can't test this!
}
```

**Issues:**
- Impossible to unit test
- Locked into SwiftData
- Business logic mixed with views

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

### Key Features

- ✅ **Clean Architecture** - Repository Pattern with protocol-first design
- ✅ **SwiftData Integration** - First-class support for SwiftData (iOS 17+)
- ✅ **Fully Testable** - Mocks and in-memory storage for unit tests
- ✅ **Secure Storage** - Keychain integration for sensitive data
- ✅ **Built-in Caching** - LRU cache with configurable TTL
- ✅ **Thread-Safe** - Swift 6 concurrency (actors, Sendable)
- ✅ **CloudKit Ready** - Optional iCloud synchronization

---

## 📋 Requirements

- **Swift:** 6.0+
- **Platforms:** iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- **Xcode:** 16.0+

---

## 🚀 Installation

### Swift Package Manager

#### For Swift Packages

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCStorage.git", from: "1.0.0")
]
```

#### For Xcode Projects

1. **File → Add Package Dependencies**
2. Enter: `https://github.com/arclabs-studio/ARCStorage.git`
3. Select version: `1.0.0` or later

---

## 📖 Usage

### Quick Start

#### 1. Define Your Model

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

#### 2. Configure in Your App

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

#### 3. Create Repository

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

#### 4. Use in ViewModel

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

### Storage Backends

#### SwiftData (Recommended)

```swift
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
let repository = SwiftDataRepository(storage: storage, cachePolicy: .default)
```

#### InMemory (Testing)

```swift
let storage = InMemoryStorage<Restaurant>()
let repository = InMemoryRepository<Restaurant>()
```

#### UserDefaults (Simple Data)

```swift
let storage = UserDefaultsStorage<Settings>()
let repository = UserDefaultsRepository<Settings>()
```

#### Keychain (Secure Data)

```swift
let storage = KeychainStorage<AuthToken>(service: "com.myapp.auth")
let repository = KeychainRepository<AuthToken>(service: "com.myapp.auth")
```

### Advanced Features

#### Caching

```swift
// Aggressive caching (1 hour TTL, 500 items)
let repository = SwiftDataRepository(storage: storage, cachePolicy: .aggressive)

// No caching (always fresh)
let repository = SwiftDataRepository(storage: storage, cachePolicy: .noCache)

// Custom policy
let customPolicy = CachePolicy(ttl: 600, maxSize: 200, strategy: .lru)
```

#### Queries with Predicates

```swift
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}
let results = try await repository.fetch(matching: predicate)
```

#### CloudKit Sync

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    isCloudKitEnabled: true
)

let monitor = CloudKitSyncMonitor()
monitor.startMonitoring()
```

---

## 🏗️ Project Structure

```
Sources/ARCStorage/
├── Core/
│   ├── Protocols/      # Repository, StorageProvider, CachePolicy
│   ├── Models/         # StorageError, QueryDescriptor, SortDescriptor
│   └── Extensions/     # Identifiable, Predicate helpers
├── Implementations/
│   ├── SwiftData/      # SwiftDataStorage, SwiftDataRepository
│   ├── InMemory/       # InMemoryStorage, InMemoryRepository
│   ├── UserDefaults/   # UserDefaultsStorage, UserDefaultsRepository
│   └── Keychain/       # KeychainStorage, KeychainRepository
├── Features/
│   ├── Cache/          # LRUCache, CacheManager
│   ├── CloudKit/       # CloudKitConfiguration, CloudKitSyncMonitor
│   └── Migration/      # MigrationPlan, MigrationHelper
└── Testing/            # MockRepository, MockStorageProvider, TestHelpers
```

---

## 🧪 Testing

ARCStorage makes testing easy with mocks:

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
}
```

### Running Tests

```bash
swift test
```

### Coverage

- **Packages:** Target 100%, minimum 80%

---

## 📐 Architecture

ARCStorage follows Clean Architecture principles:

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

For complete architecture guidelines, see [ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge).

---

## 🛠️ Development

### Prerequisites

```bash
# Install required tools
brew install swiftlint swiftformat
```

### Setup

```bash
# Clone the repository
git clone https://github.com/arclabs-studio/ARCStorage.git
cd ARCStorage

# Initialize submodules
git submodule update --init --recursive

# Build the project
swift build
```

### Available Commands

```bash
swift build          # Build the package
swift test           # Run tests
swiftlint lint       # Run SwiftLint
swiftformat --lint . # Check formatting
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `feature/your-feature`
3. Follow [ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge) standards
4. Ensure tests pass: `swift test`
5. Run quality checks: `swiftlint lint`
6. Create a pull request

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new storage backend
fix: resolve cache invalidation issue
docs: update installation instructions
```

---

## 📦 Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** - Breaking changes
- **MINOR** - New features (backwards compatible)
- **PATCH** - Bug fixes (backwards compatible)

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🔗 Related Resources

- **[ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge)** - Development standards and guidelines
- **[ARCDevTools](https://github.com/arclabs-studio/ARCDevTools)** - Quality tooling and automation
- **[Documentation](https://arclabs-studio.github.io/ARCStorage)** - Full API documentation

---

<div align="center">

Made with 💛 by **ARC Labs Studio**

[**GitHub**](https://github.com/arclabs-studio) • [**Issues**](https://github.com/arclabs-studio/ARCStorage/issues)

</div>
