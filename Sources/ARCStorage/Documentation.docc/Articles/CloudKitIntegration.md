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
    isCloudKitEnabled: true
)
let container = try config.makeContainer()
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
    @Attribute(.unique)
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
    @Attribute(.unique)
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
    @Attribute(.unique)
    var id: UUID = UUID()
    var text: String = ""
    var rating: Int = 0

    // ✅ Optional inverse relationship
    var restaurant: Restaurant?
}
```

### Index for Performance

Use `@Attribute(.unique)` on your `id` property for faster lookups:

```swift
@Model
final class Restaurant: SwiftDataEntity {
    @Attribute(.unique)  // Creates database index
    var id: UUID = UUID()
    // ...
}
```

## Monitoring Sync Status

Use ``CloudKitSyncMonitor`` to track sync status:

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

            Button("Sync Now") {
                Task {
                    try? await monitor.triggerSync()
                }
            }
            .disabled(monitor.status.isSyncing)
        }
        .task {
            await monitor.startMonitoring()
        }
    }
}
```

### Sync Status Values

The ``SyncStatus`` enum provides these states:

| Status | Description |
|--------|-------------|
| `.idle` | Not currently syncing |
| `.syncing` | Sync in progress |
| `.synced` | Sync completed successfully |
| `.error(Error)` | Sync failed with error |

## Error Handling

Handle sync errors gracefully:

```swift
if monitor.status.hasError, let error = monitor.lastError {
    switch error {
    case CloudKitSyncError.accountNotAvailable:
        // User not signed into iCloud
        showSignInPrompt()
    case CloudKitSyncError.networkError:
        // Network unavailable
        showRetryOption()
    default:
        // Other errors
        showErrorAlert(error)
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
- ``SyncStatus``

### Advanced
- ``CloudKitSyncEngineManager``
