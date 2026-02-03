# SwiftData Integration

Learn how to use ARCStorage with SwiftData for persistent storage.

## Overview

SwiftData is the recommended storage backend for ARCStorage. It provides persistent storage with automatic CloudKit synchronization support.

## Model Definition

### Basic Model

Define your model conforming to ``SwiftDataEntity``:

```swift
import SwiftData
import ARCStorage

@Model
final class Restaurant: SwiftDataEntity {
    @Attribute(.unique)  // Creates database index for O(1) lookups
    var id: UUID = UUID()
    var name: String = ""
    var cuisine: String = ""
    var rating: Double = 0.0

    init(id: UUID = UUID(), name: String, cuisine: String, rating: Double = 0.0) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.rating = rating
    }
}
```

### Using @Attribute(.unique)

Always add `@Attribute(.unique)` to your `id` property. This creates a database index that enables O(1) lookups instead of O(n) table scans:

```swift
@Model
final class Restaurant: SwiftDataEntity {
    @Attribute(.unique)  // Required for optimal performance
    var id: UUID = UUID()
    // ...
}
```

### Model with Relationships

```swift
@Model
final class Restaurant: SwiftDataEntity {
    @Attribute(.unique)
    var id: UUID = UUID()
    var name: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Review.restaurant)
    var reviews: [Review]? = []
}

@Model
final class Review: SwiftDataEntity {
    @Attribute(.unique)
    var id: UUID = UUID()
    var text: String = ""
    var rating: Int = 0

    var restaurant: Restaurant?
}
```

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
let container = try config.makeContainer()
```

See <doc:CloudKitIntegration> for detailed CloudKit setup instructions.

## Storage and Repository

### Creating Storage

```swift
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
```

### Creating Repository

```swift
let repository = SwiftDataRepository(storage: storage)
```

> Note: SwiftData provides its own internal caching through object faulting, so `CacheManager` is not used with SwiftData repositories.

## Fetching Data

### Basic Fetch

```swift
// Fetch all
let restaurants = try repository.fetchAll()

// Fetch by ID
let restaurant = try repository.fetch(id: restaurantID)
```

### Fetch with Predicate

```swift
let predicate = #Predicate<Restaurant> { restaurant in
    restaurant.rating >= 4.0 && restaurant.cuisine == "Italian"
}
let topItalian = try repository.fetch(matching: predicate)
```

### Fetch with Prefetching

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

### Advanced Fetch with Sorting and Pagination

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

## CloudKit Sync Monitoring

```swift
import ARCStorage
import SwiftUI

struct SyncStatusView: View {
    @State private var monitor = CloudKitSyncMonitor()

    var body: some View {
        VStack {
            Text("Status: \(monitor.status.description)")

            if let date = monitor.lastSyncDate {
                Text("Last sync: \(date, style: .relative)")
            }
        }
        .task {
            await monitor.startMonitoring()
        }
    }
}
```

## Schema Migrations

For schema changes between app versions, see <doc:MigrationGuide>.

## Best Practices

1. **Always use @Attribute(.unique) on id**: Enables fast O(1) lookups
2. **Use prefetching**: Avoid N+1 queries when accessing relationships
3. **Use Repositories in Domain Layer**: Never use `@Query` in ViewModels
4. **Inject Dependencies**: Pass repositories through initializers
5. **Handle CloudKit requirements**: All properties must have defaults for CloudKit
6. **Test migrations**: Always test schema migrations with sample data

## Topics

### Configuration
- ``SwiftDataConfiguration``
- ``SwiftDataEntity``

### Storage and Repository
- ``SwiftDataStorage``
- ``SwiftDataRepository``

### CloudKit
- ``CloudKitSyncMonitor``
- ``CloudKitConfiguration``

### Related Articles
- <doc:CloudKitIntegration>
- <doc:MigrationGuide>
