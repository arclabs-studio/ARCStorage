# ``ARCStorage``

Protocol-based storage abstraction that decouples domain logic from persistence.

## Overview

ARCStorage provides a unified interface for data persistence across different backends, following Clean Architecture principles with the Repository Pattern.

The library supports multiple storage backends:
- **InMemory**: Fast, ephemeral storage for testing and caching
- **UserDefaults**: Simple key-value persistence
- **Keychain**: Secure storage for sensitive data
- **SwiftData**: Modern persistence with automatic CloudKit sync

## Topics

### Core Protocols

- ``StorageProvider``
- ``Repository``
- ``SwiftDataEntity``

### Storage Implementations

- ``InMemoryStorage``
- ``UserDefaultsStorage``
- ``KeychainStorage``
- ``SwiftDataStorage``

### Repository Implementations

- ``InMemoryRepository``
- ``UserDefaultsRepository``
- ``KeychainRepository``
- ``SwiftDataRepository``

### Caching

- ``CacheManager``
- ``CachePolicy``
- ``LRUCache``

### CloudKit Integration

- ``CloudKitConfiguration``
- ``CloudKitSyncMonitor``
- ``CloudKitSyncEngineManager``

### Models

- ``StorageError``
- ``QueryDescriptor``
- ``SortDescriptor``

### Testing

- ``MockRepository``
- ``MockStorageProvider``
