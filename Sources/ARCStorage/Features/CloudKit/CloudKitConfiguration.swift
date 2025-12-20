import Foundation

/// Configuration for CloudKit synchronization.
///
/// Defines how SwiftData models sync with CloudKit, including
/// conflict resolution and sync scheduling.
///
/// ## Example
/// ```swift
/// let cloudConfig = CloudKitConfiguration(
///     containerIdentifier: "iCloud.com.myapp.container",
///     conflictResolution: .serverWins
/// )
/// ```
public struct CloudKitConfiguration: Sendable {
    /// The CloudKit container identifier.
    public let containerIdentifier: String

    /// Strategy for resolving sync conflicts.
    public let conflictResolution: ConflictResolutionStrategy

    /// Whether to sync automatically.
    public let autoSync: Bool

    /// Sync interval in seconds.
    public let syncInterval: TimeInterval

    /// Creates a new CloudKit configuration.
    ///
    /// - Parameters:
    ///   - containerIdentifier: CloudKit container ID
    ///   - conflictResolution: Conflict resolution strategy
    ///   - autoSync: Enable automatic sync
    ///   - syncInterval: Time between automatic syncs
    public init(
        containerIdentifier: String,
        conflictResolution: ConflictResolutionStrategy = .serverWins,
        autoSync: Bool = true,
        syncInterval: TimeInterval = 300
    ) {
        self.containerIdentifier = containerIdentifier
        self.conflictResolution = conflictResolution
        self.autoSync = autoSync
        self.syncInterval = syncInterval
    }
}

/// Strategies for resolving CloudKit sync conflicts.
public enum ConflictResolutionStrategy: Sendable {
    /// Server data always wins.
    case serverWins

    /// Local data always wins.
    case localWins

    /// Most recently modified wins.
    case mostRecentWins

    /// Custom resolution logic.
    case custom
}
