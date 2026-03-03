# CloudKit Integration

## Overview

ARCStorage supports optional CloudKit synchronization through SwiftData's built-in CloudKit support. When enabled, data syncs automatically across all devices signed in to the same iCloud account. Apps that don't opt in see zero changes.

## Xcode Setup

Before using CloudKit sync, configure your Xcode project:

1. **Enable iCloud capability** in Signing & Capabilities
2. **Check "CloudKit"** and add your container identifier (e.g., `iCloud.com.mycompany.myapp`)
3. **Enable Background Modes** > "Remote notifications" (required for silent push sync)

## Model Requirements

CloudKit imposes specific requirements on SwiftData models:

### Properties

All properties must be **optional** or have **default values**. CloudKit sync can create partial objects during conflict resolution.

```swift
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID = UUID()       // Default value
    var name: String = ""       // Default value
    var rating: Double?         // Optional
    var cuisineType: String?    // Optional
}
```

### Relationships

All relationships must be **optional**. Related objects may not sync simultaneously.

```swift
@Model
final class Restaurant: SwiftDataEntity {
    var id: UUID = UUID()
    var name: String = ""

    @Relationship(deleteRule: .cascade)
    var reviews: [Review]?      // Optional

    var owner: Owner?           // Optional
}
```

### Constraints

- **No ordered relationships** — CloudKit does not preserve ordering
- **`@Attribute(.unique)` is incompatible with CloudKit** — CloudKit uses its own record identifiers. Enforce uniqueness in application logic instead.

## Configuration

Use `CloudKitOption` when creating a `SwiftDataConfiguration`:

```swift
// Local-only (default)
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self, Review.self])
)

// CloudKit-enabled
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self, Review.self]),
    cloudKit: .enabled(containerIdentifier: "iCloud.com.mycompany.myapp")
)
```

## Container Creation

### `makeContainer()`

Creates a container using the exact configuration specified. If CloudKit is enabled but the user isn't signed in, container creation may still succeed but sync won't work.

```swift
let container = try config.makeContainer()
```

### `makeContainerWithFallback()` (Recommended)

Checks iCloud account status first. If the account is unavailable, falls back to a local-only container automatically. This prevents sync errors for users not signed in to iCloud.

```swift
let container = try await config.makeContainerWithFallback()
```

Use `makeContainerWithFallback()` in production apps. Use `makeContainer()` in tests or when you want explicit control.

## Monitoring Sync Status

Use `CloudKitSyncMonitor` to show sync status in your UI:

```swift
struct SyncStatusView: View {
    @State private var monitor = CloudKitSyncMonitor(
        containerIdentifier: "iCloud.com.mycompany.myapp"
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
                Text(unavailableText(for: reason))
            }
        }
        .task { await monitor.startMonitoring() }
    }

    private func unavailableText(for reason: UnavailableReason) -> String {
        switch reason {
        case .noAccount: "Sign in to iCloud"
        case .restricted: "iCloud restricted"
        case .temporarilyUnavailable: "Temporarily unavailable"
        case .couldNotDetermine: "Status unknown"
        case .error(let message): "Error: \(message)"
        }
    }
}
```

## Fallback Behavior

When iCloud is unavailable (user not signed in, restricted, etc.):

- `makeContainerWithFallback()` creates a **local-only** container
- Data is stored on-device only
- If the user later signs in to iCloud, the next app launch with `makeContainerWithFallback()` will create a CloudKit-enabled container
- Previously local-only data will **not** automatically migrate to CloudKit — this is a SwiftData limitation

## Testing

### Unit Tests

Use in-memory containers with CloudKit disabled:

```swift
let config = SwiftDataConfiguration(
    schema: Schema([Restaurant.self])
)
// Uses makeContainer() which creates local-only container
let container = try config.makeContainer()
```

### Integration Tests

CloudKit integration tests require entitlements and should live in a demo app, not package tests. The `CloudKitSyncMonitor.startMonitoring()` method calls `CKContainer.accountStatus()` which requires CloudKit entitlements.

## Limitations

- **No manual sync trigger** — SwiftData handles sync timing automatically
- **No custom record types** — SwiftData maps models to CloudKit records automatically. For custom CKRecord management, use `CloudKitSyncEngineManager` instead (separate concern).
- **Private database only** — SwiftData+CloudKit uses the private CloudKit database. For public or shared databases, use `CloudKitSyncEngineManager`.
