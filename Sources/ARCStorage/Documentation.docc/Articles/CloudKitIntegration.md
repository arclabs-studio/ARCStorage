# CloudKit Integration

Learn how to enable CloudKit synchronization with ARCStorage.

## Overview

ARCStorage provides seamless CloudKit integration through SwiftData's built-in sync capabilities. This guide covers setup, model requirements, and monitoring sync status.

## Enabling CloudKit

### Basic Setup

Enable CloudKit when creating your configuration:

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self, Review.self]),
    cloudKit: .enabled(containerIdentifier: "iCloud.com.myapp")
)
let container = try await config.makeContainerWithFallback()
```

### Xcode Project Setup

Before CloudKit sync works, configure your Xcode project:

1. **Enable iCloud capability** in your target's Signing & Capabilities
2. **Select CloudKit** from the iCloud services
3. **Create a CloudKit container** (e.g., `iCloud.com.yourcompany.yourapp`)
4. **Enable Background Modes** for remote notifications (optional but recommended)

## Model Requirements

CloudKit has specific requirements for models to sync correctly.

### Property Requirements

All properties must be optional OR have default values:

```swift
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID = UUID()          // ✅ Has default value
    var name: String = ""          // ✅ Has default value
    var description: String?       // ✅ Optional
    var rating: Double?            // ✅ Optional
    var createdAt: Date = Date()   // ✅ Has default value
}
```

### Relationship Requirements

All relationships must be optional:

```swift
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID = UUID()
    var name: String = ""

    // ✅ Optional relationship - required for CloudKit
    @Relationship(deleteRule: .cascade)
    var reviews: [Review]?

    // ✅ Optional inverse relationship
    var owner: Owner?
}

@Model
final class Review: SwiftDataEntity {
    var id: UUID = UUID()
    var text: String = ""
    var rating: Int = 0

    // ✅ Optional inverse relationship
    var restaurant: Restaurant?
}
```

### Unique Constraints

> Important: `@Attribute(.unique)` is **not compatible** with CloudKit sync.
> CloudKit uses its own record identifiers and unique constraints cause
> sync failures. Only use `@Attribute(.unique)` for local-only models:
>
> ```swift
> // ✅ Local-only model — safe to use @Attribute(.unique)
> @Model
> final class LocalSettings: SwiftDataEntity {
>     @Attribute(.unique) var id: UUID = UUID()
>     var theme: String = "default"
> }
>
> // ✅ CloudKit model — do NOT use @Attribute(.unique)
> @Model
> final class Restaurant: SwiftDataEntity {
>     var id: UUID = UUID()
>     var name: String = ""
> }
> ```

## Monitoring Sync Status

Use ``CloudKitSyncMonitor`` to track iCloud account availability:

```swift
import ARCStorage
import SwiftUI

struct SyncStatusView: View {
    @State private var monitor = CloudKitSyncMonitor(
        containerIdentifier: "iCloud.com.myapp"
    )

    var body: some View {
        HStack {
            switch monitor.state {
            case .available:
                Image(systemName: "checkmark.icloud")
                Text("iCloud available")
            case .syncing:
                ProgressView()
                Text("Checking...")
            case .unavailable(let reason):
                Image(systemName: "xmark.icloud")
                Text("Unavailable")
            }
        }
        .task {
            await monitor.startMonitoring()
        }
    }
}
```

### Sync State Values

The ``SyncState`` enum provides these states:

| State | Description |
|-------|-------------|
| `.available` | iCloud account is available and sync is ready |
| `.syncing` | A sync status check is in progress |
| `.unavailable(reason:)` | iCloud is not available |

The ``UnavailableReason`` enum provides these reasons:

| Reason | Description |
|--------|-------------|
| `.noAccount` | User is not signed in to iCloud |
| `.restricted` | iCloud access is restricted (e.g., parental controls) |
| `.couldNotDetermine` | Account status could not be determined |
| `.temporarilyUnavailable` | iCloud is temporarily unavailable |
| `.error(String)` | An error occurred while checking account status |

## Error Handling

Handle unavailable sync states:

```swift
switch monitor.state {
case .available:
    // Sync is ready
    break
case .syncing:
    // Checking status...
    break
case .unavailable(let reason):
    switch reason {
    case .noAccount:
        showSignInPrompt()
    case .restricted:
        showRestrictedAlert()
    case .temporarilyUnavailable:
        showRetryOption()
    case .couldNotDetermine:
        showRetryOption()
    case .error(let message):
        showErrorAlert(message)
    }
}
```

## Advanced: CKSyncEngine

For full control over CloudKit sync, use ``CloudKitSyncEngineManager``:

```swift
let cloudConfig = CloudKitConfiguration(
    containerIdentifier: "iCloud.com.myapp.container",
    conflictResolution: .serverWins
)

let syncEngine = CloudKitSyncEngineManager(
    configuration: cloudConfig,
    delegate: mySyncDelegate
)
try await syncEngine.start()

// Manual sync operations
try await syncEngine.fetchChanges()
try await syncEngine.sendChanges()
```

## Best Practices

1. **Test with production containers** - Development and production CloudKit containers are separate
2. **Handle offline gracefully** - CloudKit queues changes when offline
3. **Monitor for conflicts** - Implement conflict resolution strategies
4. **Use background sync** - Enable background modes for continuous sync
5. **Minimize data transfer** - Only sync necessary data

## Troubleshooting

### Sync Not Working

1. Verify iCloud is enabled in device Settings
2. Check CloudKit container identifier matches
3. Ensure all model properties follow requirements
4. Check CloudKit Dashboard for errors

### Data Not Appearing

1. Wait for initial sync to complete
2. Check both devices are signed into same iCloud account
3. Verify network connectivity
4. Check CloudKit Dashboard for record existence

## Topics

### Configuration
- ``SwiftDataConfiguration``
- ``CloudKitConfiguration``

### Monitoring
- ``CloudKitSyncMonitor``
- ``SyncState``

### Advanced
- ``CloudKitSyncEngineManager``
