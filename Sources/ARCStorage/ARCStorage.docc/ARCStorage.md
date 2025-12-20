# ``ARCStorage``

A protocol-based storage abstraction layer for iOS applications.

## Overview

ARCStorage provides a clean, testable architecture for data persistence in iOS applications. It supports multiple storage backends including SwiftData, UserDefaults, Keychain, and in-memory storage for testing.

Built with Swift 6 strict concurrency, ARCStorage ensures thread-safe operations while maintaining a simple, intuitive API.

### Key Features

- **Protocol-First Design**: Abstract storage implementations behind protocols for maximum flexibility
- **Multiple Backends**: SwiftData, UserDefaults, Keychain, and in-memory storage
- **Thread-Safe**: Built with Swift 6 concurrency features (actors, Sendable)
- **Fully Testable**: Comprehensive mocks and in-memory storage for unit tests
- **Caching**: Built-in LRU cache with configurable TTL and eviction policies
- **Type-Safe**: Leverage Swift's type system with generic protocols
- **CloudKit Ready**: Optional CloudKit synchronization support

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:SwiftDataIntegration>
- <doc:RepositoryPattern>
- <doc:Testing>

### Core Protocols

- ``StorageProvider``
- ``Repository``
- ``CachePolicy``
- ``TransactionContext``

### SwiftData Integration

- ``SwiftDataStorage``
- ``SwiftDataRepository``
- ``SwiftDataConfiguration``
- ``ModelContextProvider``

### Alternative Storage Backends

- ``InMemoryStorage``
- ``InMemoryRepository``
- ``UserDefaultsStorage``
- ``UserDefaultsRepository``
- ``KeychainStorage``
- ``KeychainRepository``

### Caching

- ``CacheManager``
- ``LRUCache``
- ``CacheStrategy``

### Testing Utilities

- ``MockRepository``
- ``MockStorageProvider``
- ``TestHelpers``
- ``TestModel``

### CloudKit Support

- ``CloudKitConfiguration``
- ``CloudKitSyncMonitor``
- ``SyncStatus``
- ``ConflictResolutionStrategy``

### Data Migration

- ``MigrationPlan``
- ``MigrationManager``
- ``MigrationHelper``
- ``MigrationContext``

### Error Handling

- ``StorageError``

### Supporting Types

- ``StorageConfiguration``
- ``QueryDescriptor``
- ``SortDescriptor``
- ``SortOrder``
