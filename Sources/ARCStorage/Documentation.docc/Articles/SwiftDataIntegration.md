# SwiftData Integration

Learn how to use ARCStorage with SwiftData for persistent storage.

## Overview

SwiftData is the recommended storage backend for ARCStorage. It provides persistent storage with automatic CloudKit synchronization support.

## Configuration

### Basic Setup

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self]),
    isCloudKitEnabled: false
)
let container = try config.makeContainer()
```

### CloudKit Setup

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

## Storage and Repository

### Creating Storage

```swift
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
```

### Creating Repository

```swift
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .default
)
```

## Cache Policies

### Default Policy

Balanced caching for most use cases:

```swift
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .default  // 30 min TTL, 100 items
)
```

### Aggressive Caching

For data that changes infrequently:

```swift
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .aggressive  // 1 hour TTL, 500 items
)
```

### No Caching

When you need fresh data every time:

```swift
let repository = SwiftDataRepository(
    storage: storage,
    cachePolicy: .noCache
)
```

### Custom Policy

```swift
let customPolicy = CachePolicy(
    ttl: 600,       // 10 minutes
    maxSize: 200,
    strategy: .lru
)
```

## Queries with Predicates

```swift
// Find high-rated Italian restaurants
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}
let results = try await repository.fetch(matching: predicate)
```

## CloudKit Sync Monitoring

```swift
let monitor = CloudKitSyncMonitor()
monitor.startMonitoring()

// Check sync status
switch monitor.syncStatus {
case .idle:
    print("Sync complete")
case .syncing:
    print("Syncing...")
case .error(let error):
    print("Sync error: \(error)")
}
```

## Best Practices

1. **Use Repositories in Domain Layer**: Never use `@Query` in ViewModels
2. **Inject Dependencies**: Pass repositories through initializers
3. **Cache Wisely**: Choose appropriate cache policies for your data
4. **Handle CloudKit Conflicts**: Implement conflict resolution strategies
