import CloudKit
import Foundation

/// The current state of CloudKit synchronization.
///
/// Use with ``CloudKitSyncMonitor`` to observe sync status in your UI.
///
/// ## Example
/// ```swift
/// switch monitor.state {
/// case .available:
///     Image(systemName: "checkmark.icloud")
/// case .syncing:
///     ProgressView()
/// case .unavailable(let reason):
///     Image(systemName: "xmark.icloud")
/// }
/// ```
public enum SyncState: Sendable, Equatable {
    /// iCloud account is available and sync is ready.
    case available

    /// iCloud account is not available.
    ///
    /// - Parameter reason: The reason sync is unavailable.
    case unavailable(reason: UnavailableReason)

    /// A sync operation is currently in progress.
    case syncing
}

/// The reason CloudKit sync is unavailable.
public enum UnavailableReason: Sendable, Equatable {
    /// The user is not signed in to iCloud.
    case noAccount

    /// iCloud access is restricted (e.g., by parental controls or MDM).
    case restricted

    /// The account status could not be determined.
    case couldNotDetermine

    /// iCloud is temporarily unavailable.
    case temporarilyUnavailable

    /// An error occurred while checking account status.
    ///
    /// - Parameter message: A human-readable description of the error.
    case error(String)
}

// MARK: - CKAccountStatus Mapping

extension SyncState {
    /// Maps a CloudKit account status to a sync state.
    ///
    /// - Parameter status: The account status reported by `CKContainer.accountStatus()`.
    /// - Returns: `.available` when the account is usable, otherwise `.unavailable(reason:)`.
    static func from(_ status: CKAccountStatus) -> SyncState {
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
