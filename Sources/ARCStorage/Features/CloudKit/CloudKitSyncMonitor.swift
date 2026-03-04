import CloudKit
import Foundation
import Observation

/// Monitors iCloud account status for CloudKit-enabled SwiftData configurations.
///
/// Observes the user's iCloud account availability and maps it to a ``SyncState``.
/// SwiftData handles the actual sync operations automatically — this monitor
/// provides UI-level awareness of whether sync is possible.
///
/// ## Example
/// ```swift
/// struct SyncStatusView: View {
///     @State private var monitor = CloudKitSyncMonitor(
///         containerIdentifier: "iCloud.com.myapp"
///     )
///
///     var body: some View {
///         HStack {
///             switch monitor.state {
///             case .available:
///                 Image(systemName: "checkmark.icloud")
///                 Text("iCloud available")
///             case .syncing:
///                 ProgressView()
///                 Text("Checking...")
///             case .unavailable(let reason):
///                 Image(systemName: "xmark.icloud")
///                 Text("Unavailable")
///             }
///         }
///         .task { await monitor.startMonitoring() }
///     }
/// }
/// ```
///
/// > Note: ``startMonitoring()`` calls `CKContainer.accountStatus()` which requires
/// > CloudKit entitlements. In package unit tests, only initial-state tests are possible.
/// > Full integration tests belong in a demo app with proper entitlements.
@Observable
@MainActor
public final class CloudKitSyncMonitor {
    /// The current sync state.
    public private(set) var state: SyncState = .available

    /// The last time sync status was checked.
    public private(set) var lastSyncDate: Date?

    /// Whether the monitor is actively observing account changes.
    public private(set) var isMonitoring = false

    /// The CloudKit container identifier.
    private let containerIdentifier: String

    /// Observer token for `CKAccountChanged` notifications.
    private var notificationToken: (any NSObjectProtocol)?

    /// Creates a new sync monitor.
    ///
    /// - Parameter containerIdentifier: The CloudKit container identifier
    ///   (e.g., `"iCloud.com.mycompany.myapp"`).
    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    /// Starts monitoring iCloud account status.
    ///
    /// Performs an initial account status check and then observes
    /// `CKAccountChanged` notifications for ongoing updates.
    public func startMonitoring() async {
        isMonitoring = true
        await checkAccountStatus()
        observeAccountChanges()
    }

    /// Stops monitoring iCloud account status.
    public func stopMonitoring() {
        isMonitoring = false
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
            notificationToken = nil
        }
    }

    // MARK: - Private

    private func checkAccountStatus() async {
        state = .syncing
        let container = CKContainer(identifier: containerIdentifier)
        do {
            let accountStatus = try await container.accountStatus()
            state = mapAccountStatus(accountStatus)
            lastSyncDate = Date()
        } catch {
            state = .unavailable(reason: .error(error.localizedDescription))
        }
    }

    private func observeAccountChanges() {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
        notificationToken = NotificationCenter.default.addObserver(forName: .CKAccountChanged,
                                                                   object: nil,
                                                                   queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAccountStatus()
            }
        }
    }

    private func mapAccountStatus(_ status: CKAccountStatus) -> SyncState {
        switch status {
        case .available:
            .available
        case .noAccount:
            .unavailable(reason: .noAccount)
        case .restricted:
            .unavailable(reason: .restricted)
        case .couldNotDetermine:
            .unavailable(reason: .couldNotDetermine)
        case .temporarilyUnavailable:
            .unavailable(reason: .temporarilyUnavailable)
        @unknown default:
            .unavailable(reason: .couldNotDetermine)
        }
    }
}
