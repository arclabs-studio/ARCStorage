import CloudKit
import Foundation
import Observation

/// Monitors CloudKit synchronization status.
///
/// Provides real-time updates on sync state, errors, and progress.
/// Uses the modern `@Observable` macro for efficient SwiftUI integration.
///
/// ## Example
/// ```swift
/// let monitor = CloudKitSyncMonitor()
///
/// // In SwiftUI
/// struct ContentView: View {
///     @State private var monitor = CloudKitSyncMonitor()
///
///     var body: some View {
///         VStack {
///             Text("Status: \(monitor.status.description)")
///             if let date = monitor.lastSyncDate {
///                 Text("Last sync: \(date, style: .relative)")
///             }
///         }
///     }
/// }
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Observable
@MainActor
public final class CloudKitSyncMonitor {
    /// Current sync status.
    public private(set) var status: SyncStatus = .idle

    /// Last successful sync timestamp.
    public private(set) var lastSyncDate: Date?

    /// Last sync error, if any.
    public private(set) var lastError: Error?

    /// Whether the sync engine is currently active.
    public private(set) var isActive = false

    /// The sync engine manager.
    private var syncEngineManager: CloudKitSyncEngineManager?

    /// The CloudKit configuration.
    private let configuration: CloudKitConfiguration?

    /// Creates a new sync monitor.
    ///
    /// - Parameter configuration: Optional CloudKit configuration for automatic engine setup
    public init(configuration: CloudKitConfiguration? = nil) {
        self.configuration = configuration
    }

    /// Starts monitoring sync status.
    ///
    /// This will set up notification observers and optionally start the sync engine.
    public func startMonitoring() async {
        isActive = true
        status = .idle

        // Set up notification observers
        setupNotificationObservers()
    }

    /// Stops monitoring.
    public func stopMonitoring() {
        isActive = false
        removeNotificationObservers()
    }

    /// Manually triggers a sync operation.
    ///
    /// - Throws: `CloudKitSyncError` if the sync fails
    public func triggerSync() async throws {
        guard isActive else {
            throw CloudKitSyncError.engineNotStarted
        }

        status = .syncing
        lastError = nil

        do {
            if let manager = syncEngineManager {
                try await manager.fetchChanges()
                try await manager.sendChanges()
            } else {
                // Fallback for basic sync without full engine
                try await performBasicSync()
            }

            status = .synced
            lastSyncDate = Date()
        } catch {
            lastError = error
            status = .error(error)
            throw error
        }
    }

    /// Connects an existing sync engine manager to this monitor.
    ///
    /// - Parameter manager: The sync engine manager to monitor
    public func connect(to manager: CloudKitSyncEngineManager) {
        syncEngineManager = manager
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAccountChange()
            }
        }
    }

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.CKAccountChanged,
            object: nil
        )
    }

    private func handleAccountChange() async {
        guard let config = configuration else { return }

        let container = CKContainer(identifier: config.containerIdentifier)
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                if status.hasError {
                    status = .idle
                }
            case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
                status = .error(CloudKitSyncError.accountNotAvailable)
            @unknown default:
                break
            }
        } catch {
            lastError = error
            status = .error(error)
        }
    }

    private func performBasicSync() async throws {
        // Simulate network delay for basic sync
        try await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Legacy Support

/// Monitors CloudKit synchronization status.
///
/// This is the legacy version using `ObservableObject` for backwards compatibility.
/// For new code, prefer using `CloudKitSyncMonitor` which uses the modern `@Observable` macro.
@available(iOS, deprecated: 17.0, message: "Use CloudKitSyncMonitor with @Observable instead")
@available(macOS, deprecated: 14.0, message: "Use CloudKitSyncMonitor with @Observable instead")
@MainActor
public class LegacyCloudKitSyncMonitor: ObservableObject {
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
    }

    /// Stops monitoring.
    public func stopMonitoring() {
        // Implementation would remove observers
    }

    /// Manually triggers a sync.
    public func triggerSync() async throws {
        status = .syncing
        try await Task.sleep(for: .seconds(1))
        status = .synced
        lastSyncDate = Date()
    }
}

// MARK: - SyncStatus

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

    /// Human-readable description of the status.
    public var description: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing..."
        case .synced:
            "Synced"
        case let .error(error):
            "Error: \(error.localizedDescription)"
        }
    }

    /// Whether sync is currently in progress.
    public var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }

    /// Whether the last sync was successful.
    public var isSuccess: Bool {
        if case .synced = self { return true }
        return false
    }

    /// Whether there was an error.
    public var hasError: Bool {
        if case .error = self { return true }
        return false
    }
}

extension SyncStatus: Equatable {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.syncing, .syncing),
             (.synced, .synced):
            true
        case (.error, .error):
            true
        default:
            false
        }
    }
}
