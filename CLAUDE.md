# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a specific test
swift test --filter ARCStorageTests.RepositoryIntegrationTests/testFullCRUDFlow

# Run tests in a specific file
swift test --filter ARCStorageTests.LRUCacheTests
```

## Architecture

ARCStorage is a protocol-based storage abstraction that decouples domain logic from persistence. It follows Clean Architecture with a Repository Pattern.

### Core Protocol Hierarchy

```
StorageProvider (low-level persistence)
      ↓
Repository (high-level domain operations + caching)
```

**StorageProvider** (`Core/Protocols/StorageProvider.swift`): Raw CRUD operations for a specific backend. Implementations: `SwiftDataStorage`, `InMemoryStorage`, `UserDefaultsStorage`, `KeychainStorage`.

**Repository** (`Core/Protocols/Repository.swift`): Business-logic interface with caching. Wraps a StorageProvider and adds cache-aside pattern via `CacheManager`.

### Implementation Pattern

Each storage backend has two types:
- `*Storage` - implements `StorageProvider`, handles raw persistence
- `*Repository` - implements `Repository`, adds caching on top of storage

Example: `SwiftDataStorage` → `SwiftDataRepository`

### Source Layout

```
Sources/ARCStorage/
├── Core/
│   ├── Protocols/      # Repository, StorageProvider, CachePolicy, TransactionContext
│   ├── Models/         # StorageError, QueryDescriptor, SortDescriptor
│   └── Extensions/     # Identifiable, Predicate helpers
├── Implementations/
│   ├── SwiftData/      # SwiftDataStorage, SwiftDataRepository, SwiftDataConfiguration
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

All entities must conform to: `Codable & Sendable & Identifiable`

For SwiftData: add `PersistentModel` (via `@Model`)

### Threading Model

- All repositories and storage providers are actors (thread-safe by design)
- Uses Swift 6 strict concurrency (`StrictConcurrency` enabled)
- All public APIs are async/await

## Key Implementation Details

**Cache-Aside Pattern**: Repositories check cache before storage on reads, update cache after writes. See `SwiftDataRepository.fetch(id:)` for the pattern.

**Error Handling**: All operations throw `StorageError` (defined in `Core/Models/StorageError.swift`).

**Testing**: Use `MockRepository<T>` for unit tests, `InMemoryRepository<T>` for integration tests. Test fixtures use pattern `TestModel.fixture1`, `TestModel.allFixtures`.
