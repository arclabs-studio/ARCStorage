import Foundation

/// Configuration for manual CloudKit synchronization via ``CloudKitSyncEngineManager``.
///
/// Use this type when you need full control over CloudKit sync with `CKSyncEngine`.
/// For automatic SwiftData+CloudKit sync, use ``SwiftDataConfiguration`` with
/// ``CloudKitOption/enabled(containerIdentifier:)`` instead — no manual configuration required.
///
/// ## Example
/// ```swift
/// let config = CloudKitConfiguration(
///     containerIdentifier: "iCloud.com.myapp.container"
/// )
/// let engine = CloudKitSyncEngineManager(
///     configuration: config,
///     delegate: myDelegate
/// )
/// try await engine.start()
/// ```
public struct CloudKitConfiguration: Sendable {
    /// The CloudKit container identifier (e.g., `"iCloud.com.mycompany.myapp"`).
    public let containerIdentifier: String

    /// Whether the sync engine syncs automatically when changes are detected.
    ///
    /// When `true`, `CKSyncEngine` pushes and fetches changes without manual calls
    /// to ``CloudKitSyncEngineManager/sendChanges()`` or ``CloudKitSyncEngineManager/fetchChanges()``.
    /// Default is `true`.
    public let autoSync: Bool

    /// Creates a new CloudKit configuration.
    ///
    /// - Parameters:
    ///   - containerIdentifier: The CloudKit container identifier
    ///   - autoSync: Enable automatic sync (default: `true`)
    public init(
        containerIdentifier: String,
        autoSync: Bool = true
    ) {
        self.containerIdentifier = containerIdentifier
        self.autoSync = autoSync
    }
}
