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

### `makeContainerReportingMode()`

Same behavior as `makeContainerWithFallback()`, but also reports **which mode** the container ended up in, so the app can tell the user that sync is not active instead of silently running local-only:

```swift
let result = try await config.makeContainerReportingMode()

switch result.mode {
case .cloudKit:
    break                                   // sync active
case .localOnly:
    break                                   // CloudKit never requested
case let .localFallback(reason):
    showBanner("iCloud sync unavailable: \(reason)")
}

let container = result.container
```

`ContainerMode.localFallback` carries the same `UnavailableReason` values used by `SyncState` (`.noAccount`, `.restricted`, `.couldNotDetermine`, `.temporarilyUnavailable`, `.error(_)`).

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
- The fallback container uses the **same backing store file** as the CloudKit configuration. A configuration created with `storeName: "arc-favres"` keeps writing to `arc-favres.store` while offline — it does not silently switch to `default.store`, so no data becomes invisible and a second container that owns `default.store` still opens
- Data is stored on-device only
- If the user later signs in to iCloud, the next app launch with `makeContainerWithFallback()` will create a CloudKit-enabled container, backed by that same file
- Previously local-only data will **not** automatically migrate to CloudKit — this is a SwiftData limitation
- Use `makeContainerReportingMode()` when you need to know that a fallback happened (e.g. to warn a premium user who is not signed in to iCloud)

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

## Deploying Schema to Production

**Important:** Before releasing your app to the App Store or TestFlight, you must deploy your CloudKit schema from the Development environment to Production via the CloudKit Console. This is a manual step that cannot be automated by any Swift package.

### Steps

1. Open [CloudKit Console](https://icloud.developer.apple.com/)
2. Select your app's container
3. Navigate to **Schema** > **Deploy Schema Changes**
4. Review the diff and click **Deploy**

### Why This Matters

- The **Development** environment auto-creates schema on the fly when your app saves records
- The **Production** environment requires an explicit schema deployment — without it, all CloudKit sync operations will fail silently for App Store users
- Schema promotion is **additive only** — you cannot delete or rename record types or fields once promoted

### When to Deploy

- Before every App Store or TestFlight release that introduces new or modified SwiftData models
- After verifying sync works correctly in the Development environment
- Test with TestFlight before the full App Store release to confirm the production schema is correct

For more details, see Apple's documentation: [Deploying an iCloud Container's Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).

## Data Size Limits

CloudKit imposes size limits on synced data:

| Storage Type | Limit | Notes |
|---|---|---|
| Inline record fields | **1 MB total** per CKRecord | All non-asset fields combined |
| `@Attribute(.externalStorage)` | **250 MB** per CKAsset | Stored as a separate file, not inline |
| CloudKit database | **10 GB** per user (private) | Shared across all apps |

### Recommendations for Binary Data

- **Thumbnails** (`thumbnailData`): Stored inline. Keep under **50 KB**. `ThumbnailGenerator` targets ≤ 200×200px at 0.4 JPEG quality.
- **Full images** (`imageData`): For CloudKit-synced models, use `@Attribute(.externalStorage)` to map to CKAsset. For local-only models, inline storage with pre-compression is simpler and avoids `.externalStorage` crashes on separate containers.
- **Never store large uncompressed binary data inline** — exceeding 1 MB per record causes silent sync failures.

### ARCPhoto (Local-Only)

`ARCPhoto` stores images **inline** because it lives in a separate local-only container
(no CloudKit sync). `ImageCompressor` pre-compresses to ≤ 1200px max dimension at
JPEG 0.8 quality (~200–500 KB), keeping the SQLite store lean.

```swift
@Model
final class ARCPhoto: SwiftDataEntity {
    var thumbnailData: Data?   // Inline (< 50 KB)
    var imageData: Data?       // Inline (pre-compressed, ~200-500 KB)
}
```

> **Note:** If your custom models sync via CloudKit and contain large binary data,
> use `@Attribute(.externalStorage)` on those fields to map to CKAsset.

## Limitations

- **No manual sync trigger** — SwiftData handles sync timing automatically
- **No custom record types** — SwiftData maps models to CloudKit records automatically. For custom CKRecord management, use `CloudKitSyncEngineManager` instead (separate concern).
- **Private database only** — SwiftData+CloudKit uses the private CloudKit database. For public or shared databases, use `CloudKitSyncEngineManager`.
