# Changelog

All notable changes to ARCStorage will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-01-21

### Added

- **SwiftDataEntity Protocol**
  - New `SwiftDataEntity` protocol for SwiftData `@Model` classes
  - Requires only `PersistentModel & Identifiable` (no `Sendable` or `Codable`)
  - Full compatibility with Swift 6 strict concurrency mode
  - Located at `Implementations/SwiftData/SwiftDataEntity.swift`

- **Example App SwiftData Demo**
  - New "SwiftData" tab demonstrating `@Model` with `SwiftDataEntity`
  - `PersistentNote` model showing Swift 6 compatible pattern
  - `PersistentNotesViewModel` with synchronous MainActor API
  - `PersistentNoteListView` with full CRUD operations

### Changed

- **SwiftDataStorage Architecture** ⚠️ Breaking Change
  - Changed from `actor` with `@ModelActor` to `@MainActor final class`
  - No longer conforms to `StorageProvider` protocol
  - Generic constraint simplified to `T: SwiftDataEntity`
  - All methods are now **synchronous** (no `async/await`)
  - Uses `modelContainer.mainContext` for all operations

- **SwiftDataRepository Architecture** ⚠️ Breaking Change
  - Changed from `actor` to `@MainActor final class`
  - No longer conforms to `Repository` protocol
  - Removed `CacheManager` usage (SwiftData has internal caching via faulting)
  - Removed `cachePolicy` parameter from initializer
  - All methods are now **synchronous** (no `async/await`)

### Why These Changes?

In Swift 6 strict concurrency, the `@Model` macro generates conformances isolated to the main actor. This makes it impossible for `@Model` classes to safely conform to `Sendable`, which was required by the previous `StorageProvider` and `Repository` protocols.

The new architecture:
- Isolates all SwiftData operations to `@MainActor`
- Removes `Sendable` requirement for SwiftData entities
- Provides synchronous API (all on MainActor, no crossing actor boundaries)
- Relies on SwiftData's internal caching instead of `CacheManager`

### Migration Guide

**Before (1.1.x):**
```swift
@Model
final class Restaurant: Identifiable, Codable, Sendable { // ❌ Won't compile in Swift 6
    var id: UUID
    var name: String
}

let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
let repository = SwiftDataRepository(storage: storage, cachePolicy: .default)

// Async API
let restaurants = try await repository.fetchAll()
```

**After (1.2.0):**
```swift
@Model
final class Restaurant: SwiftDataEntity { // ✅ Swift 6 compatible
    var id: UUID
    var name: String
}

let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
let repository = SwiftDataRepository(storage: storage)

// Synchronous API (must be on MainActor)
let restaurants = try repository.fetchAll()
```

### Notes

- Other storage backends (InMemory, UserDefaults, Keychain) are **unchanged**
- They still require `Codable & Sendable` and use async/await
- Use structs for these backends, `@Model` classes only for SwiftData

## [1.1.0] - 2026-01-05

### Added

- **Keychain Security**
  - `KeychainAccessibility` enum with 5 security levels
  - New `accessibility` parameter in `KeychainStorage` and `KeychainRepository`
  - Support for `whenPasscodeSetThisDeviceOnly` (highest security)

- **CloudKit CKSyncEngine Integration**
  - `CloudKitSyncEngineManager` - Full wrapper around Apple's `CKSyncEngine`
  - `CloudKitSyncEngineDelegate` protocol for handling sync events
  - `CloudKitSyncError` enum for sync-specific errors
  - Automatic state persistence and restoration

- **Memory Pressure Handling**
  - `MemoryPressureHandler` responds to system memory warnings
  - `MemoryPressureLevel` enum (`.warning`, `.critical`)
  - Cache automatically evicts 50% on warning, 100% on critical
  - Cross-platform support (iOS, macOS, tvOS, watchOS)

- **@Observable Migration**
  - `CloudKitSyncMonitor` now uses `@Observable` macro
  - Added `LegacyCloudKitSyncMonitor` for backwards compatibility
  - New convenience properties on `SyncStatus` (`isSyncing`, `isSuccess`, `hasError`)

### Changed

- **SwiftDataStorage Optimization**
  - `fetch(id:)` now uses local object registry for O(1) lookups
  - Batched enumeration with early exit for faster searches
  - Added documentation for `@Attribute(.unique)` index optimization

- **CacheManager**
  - New `registerForMemoryWarnings` parameter (default: `true`)
  - Added `handleMemoryPressure(level:)` public method

### Fixed

- Improved thread safety in `SwiftDataStorage` registered objects tracking

## [1.0.0] - 2025-01-15

### Added

- **Core Protocols**
  - `StorageProvider` - Low-level persistence abstraction
  - `Repository` - High-level domain operations with caching
  - `CachePolicy` - Configurable cache behavior (TTL, size, strategy)
  - `TransactionContext` - Transaction handling context

- **SwiftData Integration**
  - `SwiftDataStorage` - SwiftData-backed storage provider
  - `SwiftDataRepository` - Repository with cache-aside pattern
  - `SwiftDataConfiguration` - Container and schema configuration
  - `ModelContextProvider` - Context provider utility

- **Alternative Storage Backends**
  - `InMemoryStorage` / `InMemoryRepository` - Fast, isolated storage for testing
  - `UserDefaultsStorage` / `UserDefaultsRepository` - Simple key-value persistence
  - `KeychainStorage` / `KeychainRepository` - Secure storage for sensitive data

- **Caching**
  - `LRUCache` - Actor-based LRU cache with O(1) operations
  - `CacheManager` - TTL support and configurable eviction strategies

- **CloudKit**
  - `CloudKitConfiguration` - iCloud sync configuration
  - `CloudKitSyncMonitor` - Sync status monitoring

- **Migration**
  - `MigrationPlan` - Version-to-version migration framework
  - `MigrationHelper` - Migration coordination utilities

- **Testing Utilities**
  - `MockRepository` - Full-featured mock with call tracking
  - `MockStorageProvider` - Storage provider mock for testing
  - `TestHelpers` - Fixtures and async test utilities

- **Error Handling**
  - `StorageError` - Comprehensive error types with localized descriptions
