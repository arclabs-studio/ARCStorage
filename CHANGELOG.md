# Changelog

All notable changes to ARCStorage will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
