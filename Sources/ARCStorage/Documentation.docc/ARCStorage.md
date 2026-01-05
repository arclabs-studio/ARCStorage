# ``ARCStorage``

Protocol-based storage abstraction for iOS apps supporting SwiftData, UserDefaults, Keychain, and testing.

## Overview

ARCStorage provides a clean, testable architecture for data persistence that completely decouples your domain layer from persistence details. Built with Swift 6 strict concurrency, it offers multiple storage backends with a unified interface.

### Key Features

- **Protocol-First Design**: Abstract storage behind protocols for testability
- **Multiple Backends**: SwiftData, UserDefaults, Keychain, in-memory
- **Thread-Safe**: Built with Swift 6 actors and Sendable types
- **Built-in Caching**: LRU cache with configurable TTL, eviction strategies, and memory pressure handling
- **Secure Storage**: Keychain integration with configurable security levels
- **CloudKit Ready**: Full CKSyncEngine integration for iCloud synchronization
- **@Observable Support**: Modern SwiftUI integration using Observation framework

### The Problem

Using SwiftData's `@Query` directly in SwiftUI views creates tight coupling:

```swift
// Tightly coupled to SwiftData
struct RestaurantsView: View {
    @Query private var restaurants: [Restaurant]  // Can't test this!
}
```

### The Solution

ARCStorage provides repositories that abstract storage:

```swift
// Decoupled and testable
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

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:RepositoryPattern>
- ``Repository``
- ``StorageProvider``

### SwiftData Integration

- <doc:SwiftDataIntegration>
- ``SwiftDataStorage``
- ``SwiftDataRepository``
- ``SwiftDataConfiguration``

### Alternative Storage

- ``InMemoryStorage``
- ``InMemoryRepository``
- ``UserDefaultsStorage``
- ``UserDefaultsRepository``
- ``KeychainStorage``
- ``KeychainRepository``

### Caching

- ``CachePolicy``
- ``CacheManager``
- ``LRUCache``

### Testing

- <doc:Testing>
- ``MockRepository``
- ``MockStorageProvider``

### CloudKit

- ``CloudKitConfiguration``
- ``CloudKitSyncMonitor``

### Migration

- ``MigrationPlan``
- ``MigrationHelper``

### Error Handling

- ``StorageError``
