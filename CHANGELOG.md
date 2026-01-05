# Changelog

All notable changes to ARCStorage will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
