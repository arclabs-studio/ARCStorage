# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the package
swift build                # or: make build

# Run all tests (parallel)
swift test --parallel      # or: make test

# Run a specific test
swift test --filter ARCStorageTests.RepositoryIntegrationTests/testFullCRUDFlow

# Run tests in a specific file
swift test --filter ARCStorageTests.LRUCacheTests

# Linting and formatting
make lint                  # Run SwiftLint
make format                # Check formatting (dry-run)
make fix                   # Apply SwiftFormat

# Clean build artifacts
make clean
```

## Architecture

ARCStorage is a protocol-based storage abstraction that decouples domain logic from persistence. It follows Clean Architecture with a Repository Pattern.

### Core Protocol Hierarchy

```
StorageProvider (low-level persistence, requires Sendable)
      ↓
Repository (high-level domain operations + caching, requires Sendable)

SwiftDataEntity (SwiftData-specific, no Sendable required)
      ↓
SwiftDataStorage / SwiftDataRepository (standalone, Swift 6 compatible)
```

**StorageProvider** (`Core/Protocols/StorageProvider.swift`): Raw CRUD operations for a specific backend. Implementations: `InMemoryStorage`, `UserDefaultsStorage`, `KeychainStorage`. Requires `Sendable` entities.

**Repository** (`Core/Protocols/Repository.swift`): Business-logic interface with caching. Wraps a StorageProvider and adds cache-aside pattern via `CacheManager`. Requires `Sendable` entities.

**SwiftDataEntity** (`Implementations/SwiftData/SwiftDataEntity.swift`): Protocol for SwiftData `@Model` classes. Does NOT require `Sendable` or `Codable` (incompatible with Swift 6 strict concurrency for `@Model` classes).

### Implementation Pattern

For **InMemory, UserDefaults, Keychain** (struct-based entities):
- `*Storage` - implements `StorageProvider`, handles raw persistence
- `*Repository` - implements `Repository`, adds caching on top of storage

For **SwiftData** (`@Model` classes):
- `SwiftDataStorage<T: SwiftDataEntity>` - `@MainActor` class, does NOT implement `StorageProvider`
- `SwiftDataRepository<T: SwiftDataEntity>` - `@MainActor` class, does NOT implement `Repository`

> **Why `@MainActor`?** In Swift 6 strict concurrency, `@Model` classes cannot conform to `Sendable` because the macro generates main-actor-isolated conformances. All SwiftData operations must occur on the main actor. SwiftData provides its own caching (faulting), so `CacheManager` is not needed.

### Source Layout

```
Sources/ARCStorage/
├── Core/
│   ├── Protocols/      # Repository, StorageProvider, CachePolicy, TransactionContext
│   ├── Models/         # StorageError, QueryDescriptor, SortDescriptor
│   └── Extensions/     # Identifiable, Predicate helpers
├── Implementations/
│   ├── SwiftData/      # SwiftDataEntity, SwiftDataStorage, SwiftDataRepository, SwiftDataConfiguration
│   ├── InMemory/       # InMemoryStorage, InMemoryRepository
│   ├── UserDefaults/   # UserDefaultsStorage, UserDefaultsRepository
│   └── Keychain/       # KeychainStorage, KeychainRepository
├── Features/
│   ├── Cache/          # LRUCache, CacheManager
│   ├── CloudKit/       # CloudKitConfiguration, CloudKitSyncMonitor
│   └── Migration/      # MigrationPlan, MigrationHelper
└── Testing/            # MockRepository, MockStorageProvider, TestHelpers
```

### Type Constraints

**For InMemory, UserDefaults, Keychain:** Entities must conform to `Codable & Sendable & Identifiable`

**For SwiftData:** Entities must conform to `SwiftDataEntity` (which requires `PersistentModel & Identifiable`). Do NOT add `Sendable` or `Codable` - these are incompatible with `@Model` in Swift 6.

### Threading Model

- Non-SwiftData repositories and storage providers are actors (thread-safe by design)
- SwiftData storage/repository are `@MainActor` isolated (required for `@Model` compatibility)
- Uses Swift 6 strict concurrency (`StrictConcurrency` enabled)
- Non-SwiftData APIs are async/await, SwiftData APIs are synchronous (all on MainActor)

## Key Implementation Details

**Cache-Aside Pattern**: Non-SwiftData repositories check cache before storage on reads, update cache after writes. See `InMemoryRepository.fetch(id:)` or `UserDefaultsRepository.fetch(id:)` for the pattern.

**SwiftData Caching**: `SwiftDataRepository` does NOT use `CacheManager` because SwiftData entities cannot be `Sendable`. SwiftData provides its own internal caching through object faulting.

**Error Handling**: All operations throw `StorageError` (defined in `Core/Models/StorageError.swift`).

**Testing**: Use `MockRepository<T>` for unit tests with `Sendable` entities, `InMemoryRepository<T>` for integration tests. For SwiftData tests, use actual `@Model` classes with `SwiftDataEntity` conformance.

## Testing Patterns

**Test Fixtures** (defined in `Testing/TestHelpers.swift`):
- `TestModel.fixture1`, `.fixture2`, `.fixture3` - Deterministic UUIDs for assertions
- `TestModel.allFixtures` - Array of all fixtures
- `SimpleTestModel.fixture1`, `.fixture2` - String ID variants for UserDefaults/Keychain

**SwiftData Test Setup** (in-memory container):
```swift
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([YourModel.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
```

**MockRepository Tracking** (for verifying ViewModel calls):
- `mockRepo.saveCallCount`, `fetchAllCallCount`, `fetchCallCount`, `deleteCallCount`
- `mockRepo.shouldThrowError = .notFound(...)` - Simulate errors
- `mockRepo.mockEntities = [...]` - Inject test data
