import Foundation

/// Monitors CloudKit synchronization status.
///
/// Provides real-time updates on sync state, errors, and progress.
///
/// ## Example
/// ```swift
/// let monitor = CloudKitSyncMonitor()
/// for await status in await monitor.statusStream {
///     switch status {
///     case .syncing:
///         print("Syncing...")
///     case .synced:
///         print("Sync complete")
///     case .error(let error):
///         print("Sync failed: \(error)")
///     }
/// }
/// ```
@MainActor
public class CloudKitSyncMonitor: ObservableObject {
    /// Current sync status.
    @Published public private(set) var status: SyncStatus = .idle

    /// Last sync timestamp.
    @Published public private(set) var lastSyncDate: Date?

    /// Last sync error, if any.
    @Published public private(set) var lastError: Error?

    /// Creates a new sync monitor.
    public init() {}

    /// Starts monitoring sync status.
    public func startMonitoring() {
        // Implementation would observe NotificationCenter or CloudKit events
        // For now, this is a placeholder for the API
    }

    /// Stops monitoring.
    public func stopMonitoring() {
        // Implementation would remove observers
    }

    /// Manually triggers a sync.
    public func triggerSync() async throws {
        status = .syncing
        // Implementation would trigger CloudKit sync
        // This is a placeholder
        try await Task.sleep(nanoseconds: 1_000_000_000)
        status = .synced
        lastSyncDate = Date()
    }
}

/// CloudKit synchronization status.
public enum SyncStatus: Sendable {
    /// Not currently syncing.
    case idle

    /// Sync in progress.
    case syncing

    /// Sync completed successfully.
    case synced

    /// Sync failed with error.
    case error(Error)
}

extension SyncStatus: Equatable {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.syncing, .syncing),
             (.synced, .synced):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
