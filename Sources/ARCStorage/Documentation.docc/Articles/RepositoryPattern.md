# Repository Pattern

Understand the architecture behind ARCStorage.

## Overview

ARCStorage follows Clean Architecture principles with a two-tier abstraction:

```
StorageProvider (low-level persistence)
      ↓
Repository (high-level domain operations + caching)
```

## Protocol Hierarchy

### StorageProvider

Low-level persistence abstraction for raw CRUD operations:

```swift
public protocol StorageProvider<Entity>: Sendable {
    associatedtype Entity: Codable & Sendable & Identifiable

    func save(_ entity: Entity) async throws
    func fetchAll() async throws -> [Entity]
    func fetch(id: Entity.ID) async throws -> Entity?
    func delete(id: Entity.ID) async throws
}
```

### Repository

High-level domain interface with caching:

```swift
public protocol Repository<Entity>: Sendable {
    associatedtype Entity: Codable & Sendable & Identifiable

    func save(_ entity: Entity) async throws
    func fetchAll() async throws -> [Entity]
    func fetch(id: Entity.ID) async throws -> Entity?
    func delete(id: Entity.ID) async throws
    func invalidateCache() async
}
```

## Implementation Pattern

Each storage backend follows the same pattern:

1. **Storage** - Implements `StorageProvider`, handles raw persistence
2. **Repository** - Implements `Repository`, wraps storage with caching

### Example

```swift
// Storage handles raw persistence
let storage = SwiftDataStorage<Restaurant>(modelContainer: container)

// Repository adds caching on top
let repository = SwiftDataRepository(storage: storage)
```

## Cache-Aside Pattern

Repositories implement cache-aside pattern:

```swift
public func fetch(id: T.ID) async throws -> T? {
    // 1. Check cache first
    if let cached = await cache.get(id) {
        return cached
    }

    // 2. Fetch from storage
    guard let entity = try await storage.fetch(id: id) else {
        return nil
    }

    // 3. Update cache for future access
    await cache.set(entity, for: id)

    return entity
}
```

## Type Constraints

All entities must conform to:

- `Codable` - Serialization support
- `Sendable` - Thread-safety for Swift 6
- `Identifiable` - Unique identification

For SwiftData, also add `PersistentModel` via `@Model`.

## Threading Model

- All repositories and storage providers are **actors**
- Thread-safe by design without manual locks
- All public APIs are `async/await`

## Dependency Flow

```
Apps
 └─→ Domain Repositories (your code)
      └─→ ARCStorage Repository
           └─→ ARCStorage StorageProvider
                └─→ Storage Backend (SwiftData, etc.)
```

**Critical Rule**: Dependencies flow **inward**. Domain layer should not know about storage implementation details.
