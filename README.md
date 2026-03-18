# 🗄️ ARCStorage

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20watchOS%2010%20%7C%20tvOS%2017-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.4.0-blue.svg)

**Protocol-based storage abstraction for iOS apps supporting SwiftData, UserDefaults, Keychain, Preferences, Photos, CloudKit, and testing.**

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
- ✅ **Swift 6 Compatible** - Full strict concurrency support for `@Model` classes
- ✅ **Fully Testable** - Mocks and in-memory storage for unit tests
- ✅ **Secure Storage** - Keychain integration for sensitive data
- ✅ **Preferences** - Synchronous key-value storage for simple app configuration
- ✅ **Built-in Caching** - LRU cache with configurable TTL
- ✅ **Thread-Safe** - Swift 6 concurrency (actors, Sendable, MainActor)
- ✅ **CloudKit Ready** - Optional iCloud synchronization with sync monitoring and graceful fallback
- ✅ **Relationship Prefetching** - Avoid N+1 queries with built-in prefetching
- ✅ **Schema Migrations** - VersionedSchema support with custom migration stages
- ✅ **Photo Attachments** - `ARCPhoto` model + `PhotoRepository` for binary image storage with off-thread auto-thumbnailing
- ✅ **Multiple Containers** - `storeName` parameter prevents `default.store` conflicts when using several `ModelContainer`s

---

## ⚡ Swift 6 Compatibility

ARCStorage v1.2+ provides full Swift 6 strict concurrency support for SwiftData `@Model` classes.

### The Problem

In Swift 6, the `@Model` macro generates conformances isolated to the main actor. This makes it impossible for `@Model` classes to safely conform to `Sendable`:

```swift
// ❌ This won't compile in Swift 6 strict concurrency
@Model
final class Restaurant: Identifiable, Codable, Sendable {
    var id: UUID
    var name: String
}

// Error: Main actor-isolated conformance of 'Restaurant' to 'Decodable'
// cannot satisfy conformance requirement for a 'Sendable' type parameter
```

### The Solution

ARCStorage provides `SwiftDataEntity`, a protocol that only requires `PersistentModel & Identifiable`:

```swift
// ✅ Swift 6 compatible
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
```

### Architecture Differences

| Feature | SwiftData | Other Backends |
|---------|-----------|----------------|
| Entity Protocol | `SwiftDataEntity` | `Codable & Sendable & Identifiable` |
| Isolation | `@MainActor` | `actor` |
| API | Synchronous | `async/await` |
| Caching | SwiftData internal | `CacheManager` |
| Protocol Conformance | Standalone | `Repository` / `StorageProvider` |

### Usage Pattern

```swift
// SwiftData (synchronous, MainActor)
@MainActor
class MyViewModel {
    let repository: SwiftDataRepository<Restaurant>

    func load() {
        let items = try repository.fetchAll()  // No await needed
    }
}

// Other backends (async)
class MyViewModel {
    let repository: InMemoryRepository<Note>

    func load() async {
        let items = try await repository.fetchAll()  // Async
    }
}
```

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
import ARCStorage

@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID
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

> **Note:** SwiftData models conform to `SwiftDataEntity` instead of `Codable` or `Sendable`. This is required for Swift 6 strict concurrency compatibility. See [Swift 6 Compatibility](#-swift-6-compatibility) for details.

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
            cloudKit: .enabled(containerIdentifier: "iCloud.com.example.myapp")
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
@MainActor
final class RestaurantRepository {
    private let repository: SwiftDataRepository<Restaurant>

    init(modelContainer: ModelContainer) {
        let storage = SwiftDataStorage<Restaurant>(modelContainer: modelContainer)
        self.repository = SwiftDataRepository(storage: storage)
    }

    func fetchAll() throws -> [Restaurant] {
        try repository.fetchAll()
    }

    func save(_ restaurant: Restaurant) throws {
        try repository.save(restaurant)
    }
}
```

> **Note:** SwiftData repositories are `@MainActor` isolated and use synchronous methods. No `async/await` needed!

#### 4. Use in ViewModel

```swift
import ARCLogger

@MainActor
@Observable
final class RestaurantsViewModel {
    private(set) var restaurants: [Restaurant] = []
    private let repository: RestaurantRepository
    private let logger = ARCLogger(category: "RestaurantsViewModel")

    init(repository: RestaurantRepository) {
        self.repository = repository
    }

    func loadRestaurants() {
        do {
            restaurants = try repository.fetchAll()
            logger.info("Loaded restaurants", metadata: [
                "count": .public(String(restaurants.count))
            ])
        } catch {
            logger.error("Failed to load restaurants", metadata: [
                "error": .public(error.localizedDescription)
            ])
        }
    }
}
```

### Storage Backends

#### SwiftData (Recommended)

```swift
// Model must conform to SwiftDataEntity (not Sendable/Codable)
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID
    var name: String
}

// Create storage and repository (both @MainActor)
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
let repository = SwiftDataRepository(storage: storage)

// Synchronous API (on MainActor)
let restaurants = try repository.fetchAll()
try repository.save(restaurant)
try repository.delete(id: restaurant.id)
```

> **Important:** SwiftData storage/repository are `@MainActor` isolated with synchronous methods. SwiftData's internal faulting provides caching, so no `CacheManager` is used.

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
// Default security (accessible when unlocked)
let storage = KeychainStorage<AuthToken>(service: "com.myapp.auth")

// High security - requires device passcode
let secureStorage = KeychainStorage<AuthToken>(
    service: "com.myapp.auth",
    accessibility: .whenPasscodeSetThisDeviceOnly
)

// Repository with security level
let repository = KeychainRepository<AuthToken>(
    service: "com.myapp.auth",
    accessibility: .whenUnlockedThisDeviceOnly
)
```

**Security Levels (`KeychainAccessibility`):**
- `.whenUnlocked` - Default, accessible when device is unlocked
- `.whenUnlockedThisDeviceOnly` - Same, but won't sync to new devices
- `.afterFirstUnlock` - For background operations
- `.whenPasscodeSetThisDeviceOnly` - Most secure, requires passcode

#### Preferences (Synchronous Key-Value)

`PreferenceStorage` provides synchronous access to simple app configuration — ideal
for use in `init()` and non-async contexts where `UserDefaultsRepository` (which is
async) would require wrapping:

```swift
// Define type-safe preference keys
enum AppPreferences {
    struct DarkModeEnabled: PreferenceKey {
        static let key = "app.darkMode"
        static let defaultValue = false
    }

    struct FontSize: PreferenceKey {
        static let key = "app.fontSize"
        static let defaultValue = 16
    }
}

// Use PreferenceStorage — no async required
let preferences = PreferenceStorage()  // defaults: .standard UserDefaults, "ARCPrefs" prefix
let isDark = preferences.get(AppPreferences.DarkModeEnabled.self)       // → false
preferences.set(true, for: AppPreferences.DarkModeEnabled.self)

// Inject via protocol for testability
final class AppCoordinator {
    private let preferences: PreferenceStorageProtocol

    init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
        self.preferences = preferences
        if !preferences.get(AppPreferences.OnboardingCompleted.self) {
            showOnboarding()
        }
    }
}

// In tests — use MockPreferenceStorage
let mock = MockPreferenceStorage()
mock.setMockValue(true, for: AppPreferences.DarkModeEnabled.self)
let coordinator = AppCoordinator(preferences: mock)
```

> **PreferenceStorage vs UserDefaultsStorage:** Use `PreferenceStorage` for simple
> flags and scalar values that need synchronous access. Use `UserDefaultsRepository`
> when you have entity-based models or need the async/await `Repository` interface.

### Advanced Features

#### Caching

Caching is available for InMemory, UserDefaults, and Keychain repositories:

```swift
// Aggressive caching (1 hour TTL, 500 items)
let repository = InMemoryRepository<Note>(cachePolicy: .aggressive)

// No caching (always fresh)
let repository = InMemoryRepository<Note>(cachePolicy: .noCache)

// Custom policy
let customPolicy = CachePolicy(ttl: 600, maxSize: 200, strategy: .lru)
let repository = InMemoryRepository<Note>(cachePolicy: customPolicy)
```

> **Note:** `SwiftDataRepository` does not use `CacheManager`. SwiftData provides its own internal caching through object faulting.

#### Queries with Predicates

```swift
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}
let results = try repository.fetch(matching: predicate)
```

#### Relationship Prefetching

Avoid N+1 query problems by prefetching relationships:

```swift
// Prefetch reviews when fetching restaurants
let restaurants = try repository.fetchAll(
    prefetching: [\Restaurant.reviews]
)

// Accessing reviews won't trigger additional queries
for restaurant in restaurants {
    print(restaurant.reviews?.count ?? 0)
}
```

#### Advanced Fetch with Sorting and Pagination

```swift
let predicate = #Predicate<Restaurant> { $0.isOpen }
let restaurants = try repository.fetch(
    matching: predicate,
    sortedBy: [Foundation.SortDescriptor(\.rating, order: .reverse)],
    limit: 20,
    offset: 0,
    prefetching: [\Restaurant.reviews]
)
```

#### CloudKit Sync

```swift
// Enable CloudKit in SwiftDataConfiguration
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    cloudKit: .enabled(containerIdentifier: "iCloud.com.example.myapp")
)

// Graceful fallback: falls back to local-only if iCloud is unavailable
let container = try await config.makeContainerWithFallback()

// Monitor sync status in SwiftUI (@Observable, @MainActor)
let monitor = CloudKitSyncMonitor(containerIdentifier: "iCloud.com.example.myapp")
await monitor.startMonitoring()

// In SwiftUI — observe SyncState for UI feedback
struct SyncStatusView: View {
    @State private var monitor = CloudKitSyncMonitor(containerIdentifier: "iCloud.com.example.myapp")

    var body: some View {
        switch monitor.syncState {
        case .available:    Label("Synced", systemImage: "checkmark.icloud")
        case .syncing:      Label("Syncing…", systemImage: "arrow.clockwise.icloud")
        case .unavailable:  Label("iCloud unavailable", systemImage: "xmark.icloud")
        }
    }
}
```

#### Multiple Containers (`storeName`)

When an app uses more than one `ModelContainer` (e.g. a CloudKit-synced store plus a
local-only photo store), both containers default to `default.store`. Pass a unique
`storeName` to prevent schema conflicts:

```swift
// Primary CloudKit store → default.store
let restaurantConfig = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    cloudKit: .enabled(containerIdentifier: "iCloud.com.example.myapp")
)
let restaurantContainer = try restaurantConfig.makeContainer()

// Local-only photo store → arc-photos.store
let photoConfig = SwiftDataConfiguration(
    schema: Schema([ARCPhoto.self]),
    storeName: "arc-photos"
)
let photoContainer = try photoConfig.makeContainer()
let photoRepository = SwiftDataPhotoRepository(modelContainer: photoContainer)
```

> **Why separate containers?** CloudKit requires every relationship to have a declared
> inverse. `ARCPhoto` has no inverse back to the parent entity, so including it in a
> CloudKit container triggers a schema validation crash at launch.

#### Advanced CloudKit with CKSyncEngine

For full control over CloudKit sync, use `CloudKitSyncEngineManager`:

```swift
let cloudConfig = CloudKitConfiguration(
    containerIdentifier: "iCloud.com.myapp.container",
    conflictResolution: .serverWins
)

let syncEngine = CloudKitSyncEngineManager(
    configuration: cloudConfig,
    delegate: mySyncDelegate
)
try await syncEngine.start()

// Manual sync
try await syncEngine.fetchChanges()
try await syncEngine.sendChanges()
```

#### Memory-Aware Caching

Cache automatically responds to system memory pressure:

```swift
// Cache clears 50% on memory warning, 100% on critical
let cache = CacheManager<UUID, Restaurant>(policy: .default)

// Disable automatic memory handling if needed
let cache = CacheManager<UUID, Restaurant>(
    policy: .default,
    registerForMemoryWarnings: false
)
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
│   ├── SwiftData/      # SwiftDataEntity, SwiftDataStorage, SwiftDataRepository, SwiftDataConfiguration
│   ├── InMemory/       # InMemoryStorage, InMemoryRepository
│   ├── UserDefaults/   # UserDefaultsStorage, UserDefaultsRepository
│   ├── Keychain/       # KeychainStorage, KeychainRepository, KeychainAccessibility
│   └── Preferences/    # PreferenceKey, PreferenceStorage, PreferenceStorageProtocol
├── Features/
│   ├── Cache/          # LRUCache, CacheManager, MemoryPressureHandler
│   ├── CloudKit/       # CloudKitSyncEngine, CloudKitSyncMonitor, CloudKitConfiguration
│   ├── Migration/      # MigrationPlan, MigrationHelper
│   └── Photos/         # ARCPhoto, PhotoRepository, SwiftDataPhotoRepository, ThumbnailGenerator
└── Testing/            # MockRepository, MockStorageProvider, MockPreferenceStorage, TestHelpers
```

### Photo Attachments

ARCStorage includes a first-class photo attachment system — useful for attaching images to any SwiftData entity (visits, notes, profiles, etc.).

#### 1. Set up a dedicated photo container

`ARCPhoto` must live in a **separate local-only container** from any CloudKit-synced
models (CloudKit requires inverse relationships; `ARCPhoto` has none):

```swift
// CloudKit store → default.store
let mainConfig = SwiftDataConfiguration(
    schema: Schema([Visit.self]),
    cloudKit: .enabled(containerIdentifier: "iCloud.com.example.app")
)
let mainContainer = try mainConfig.makeContainer()

// Photo store (local-only) → arc-photos.store
let photoConfig = SwiftDataConfiguration(
    schema: Schema([ARCPhoto.self]),
    storeName: "arc-photos"
)
let photoContainer = try photoConfig.makeContainer()
```

#### 2. Add a cascade-delete photo relationship to your entity

```swift
@Model
final class Visit: SwiftDataEntity {
    var id: UUID = UUID()
    var title: String = ""

    // Photos auto-delete when the parent visit is deleted
    @Relationship(deleteRule: .cascade)
    var photos: [ARCPhoto]? = []
}
```

#### 3. Create a `SwiftDataPhotoRepository` at the composition root

```swift
let photoRepository = SwiftDataPhotoRepository(modelContainer: photoContainer)
```

#### 4. Add, fetch, and delete photos

```swift
// add is async — thumbnail generation runs off the main thread
let photo = try await photoRepository.add(
    imageData: jpegData,      // Full-size JPEG from PhotosPicker
    caption: "Dinner night",
    sortOrder: 0
)

// Fetch specific photos by persistent identifier
let ids = visit.photos?.map(\.persistentModelID) ?? []
let photos = try photoRepository.photos(withIDs: ids)

// Delete a single photo
try photoRepository.delete(id: photo.persistentModelID)

// Delete all photos for a visit
try photoRepository.deleteAll(visit.photos ?? [])
```

#### How thumbnails work

`SwiftDataPhotoRepository.add()` automatically generates a compressed JPEG thumbnail (≤ 200×200 px, targeting < 50 KB) via `ThumbnailGenerator`:

| Property | Storage | Purpose |
|----------|---------|---------|
| `thumbnailData` | Inline in SQLite | Fast list / carousel rendering |
| `imageData` | `@Attribute(.externalStorage)` → CKAsset | Full-size viewer |

#### CloudKit compatibility

`ARCPhoto` is designed CloudKit-safe from the start:
- All properties have defaults or are `Optional`
- No `@Attribute(.unique)` (incompatible with CloudKit sync)
- `imageData` maps to a CloudKit **CKAsset** when sync is enabled

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
