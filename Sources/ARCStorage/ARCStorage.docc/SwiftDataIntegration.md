# SwiftData Integration

Deep dive into using ARCStorage with SwiftData.

## Overview

ARCStorage provides first-class support for SwiftData, Apple's modern persistence framework. This guide covers advanced SwiftData features including CloudKit sync, migrations, and performance optimization.

## SwiftData Requirements

Your models must conform to:

```swift
@Model
final class YourModel: Identifiable, Codable, Sendable {
    @Attribute(.unique) var id: UUID
    // ... other properties
}
```

### Protocol Requirements

- **PersistentModel**: SwiftData's model protocol
- **Identifiable**: Provides unique ID
- **Codable**: Enables JSON encoding/decoding
- **Sendable**: Required for Swift concurrency

## Configuration Options

### Basic Configuration

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self, Review.self]),
    isCloudKitEnabled: false,
    isAutosaveEnabled: true
)
```

### CloudKit Sync

Enable iCloud synchronization:

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    isCloudKitEnabled: true
)

let cloudConfig = CloudKitConfiguration(
    containerIdentifier: "iCloud.com.myapp.container",
    conflictResolution: .mostRecentWins
)
```

Remember to:
1. Add CloudKit capability in Xcode
2. Configure container identifier
3. Handle sync conflicts

## Thread Safety

ARCStorage uses `@ModelActor` for thread-safe operations:

```swift
@ModelActor
public actor SwiftDataStorage<T>: StorageProvider {
    // All operations are automatically serialized
}
```

Benefits:
- No data races
- Safe concurrent access
- Automatic context management

## Advanced Queries

### Predicate-Based Fetching

```swift
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}

let topItalian = try await repository.fetch(matching: predicate)
```

### Sorting

```swift
let descriptor = QueryDescriptor<Restaurant>(
    predicate: #Predicate { $0.rating >= 4.0 },
    sortBy: [
        SortDescriptor(\.rating, order: .descending),
        SortDescriptor(\.name, order: .ascending)
    ],
    limit: 10
)
```

## Performance Tips

### 1. Use Caching Wisely

```swift
// For frequently accessed data
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .aggressive
)

// For always-fresh data
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .noCache
)
```

### 2. Batch Operations

```swift
// More efficient than individual saves
let restaurants = [restaurant1, restaurant2, restaurant3]
try await repository.saveAll(restaurants)
```

### 3. Background Operations

```swift
actor DataImporter {
    let repository: SwiftDataRepository<Restaurant>

    func importData() async throws {
        // Runs on background actor
        let restaurants = try await fetchFromAPI()
        try await repository.saveAll(restaurants)
    }
}
```

## Migrations

### Creating a Migration

```swift
let migration = MigrationPlan(
    sourceVersion: "1.0",
    destinationVersion: "2.0"
) { context in
    // Transform data
    // Add new fields
    // Update relationships
}

let manager = MigrationManager()
await manager.addPlan(migration)
try await manager.migrate(from: "1.0", to: "2.0")
```

### Versioning Strategy

```swift
@Model
final class RestaurantV1 {
    var id: UUID
    var name: String
}

@Model
final class RestaurantV2 {
    var id: UUID
    var name: String
    var rating: Double  // New field
}
```

## Error Handling

```swift
do {
    try await repository.save(restaurant)
} catch let error as StorageError {
    switch error {
    case .saveFailed(let underlying):
        print("Save failed: \(underlying)")
    case .invalidData:
        print("Data validation failed")
    default:
        print("Storage error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## CloudKit Sync Monitoring

```swift
@MainActor
class SyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    private let monitor = CloudKitSyncMonitor()

    func startMonitoring() {
        monitor.startMonitoring()

        // Observe status changes
        monitor.$status
            .assign(to: &$syncStatus)
    }

    func triggerSync() async throws {
        try await monitor.triggerSync()
    }
}
```

## Best Practices

1. **Always use repositories, never `@Query`**
   - Keeps domain logic testable
   - Allows easy backend swapping

2. **Configure appropriate cache policies**
   - Use `.aggressive` for rarely-changing data
   - Use `.default` for normal data
   - Use `.noCache` for always-fresh data

3. **Handle errors gracefully**
   - SwiftData errors
   - Network errors (for CloudKit)
   - Validation errors

4. **Test with in-memory storage**
   - Fast tests
   - No side effects
   - Easy to reset

## See Also

- ``SwiftDataConfiguration``
- ``SwiftDataStorage``
- ``SwiftDataRepository``
- ``CloudKitConfiguration``
- ``MigrationPlan``
