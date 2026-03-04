import CloudKit
import Foundation

/// A wrapper around `CKSyncEngine` for manual CloudKit record synchronization.
///
/// Use this class when you need full control over which records sync and how they
/// are serialized. For automatic SwiftData+CloudKit sync, use ``SwiftDataConfiguration``
/// with ``CloudKitOption/enabled(containerIdentifier:)`` — no manual sync engine needed.
///
/// ## Usage
///
/// 1. Implement ``CloudKitSyncEngineDelegate`` in an actor (e.g. your data store).
/// 2. Create and start the engine early in your app's lifecycle.
/// 3. Call ``addPendingRecordZoneChanges(_:)`` whenever local data changes.
///
/// ```swift
/// actor MyDataStore: CloudKitSyncEngineDelegate {
///     var engine: CloudKitSyncEngineManager?
///
///     func setUp() async throws {
///         let config = CloudKitConfiguration(
///             containerIdentifier: "iCloud.com.myapp.container"
///         )
///         engine = CloudKitSyncEngineManager(configuration: config, delegate: self)
///         try await engine?.start()
///     }
///
///     // Provide records to push to CloudKit
///     func syncEngine(
///         nextRecordZoneChangeBatchFor context: CKSyncEngine.SendChangesContext
///     ) async -> CKSyncEngine.RecordZoneChangeBatch? {
///         // Return a batch of CKRecords to upload, or nil when done
///         return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: context.options.scope.changes) { id in
///             // Map your local model to a CKRecord
///             return myCKRecord(for: id)
///         }
///     }
///
///     // Handle records fetched from CloudKit
///     func syncEngine(
///         didFetchRecordZoneChanges changes: CKSyncEngine.Event.FetchedRecordZoneChanges
///     ) async {
///         for modification in changes.modifications {
///             // Apply the downloaded CKRecord to your local store
///             apply(modification.record)
///         }
///         for deletion in changes.deletions {
///             // Remove the deleted record from your local store
///             delete(deletion.recordID)
///         }
///     }
/// }
/// ```
///
/// ## Topics
/// ### Lifecycle
/// - ``init(configuration:delegate:stateKey:)``
/// - ``start()``
/// - ``stop()``
///
/// ### Sync Operations
/// - ``sendChanges()``
/// - ``fetchChanges()``
/// - ``addPendingRecordZoneChanges(_:)``
/// - ``addPendingDatabaseChanges(_:)``
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) public actor CloudKitSyncEngineManager {
    /// The underlying CKSyncEngine instance.
    private var syncEngine: CKSyncEngine?

    /// The CloudKit configuration.
    private let configuration: CloudKitConfiguration

    /// The delegate for handling sync events.
    private weak var delegate: (any CloudKitSyncEngineDelegate)?

    /// User defaults key for persisting sync state.
    private let stateKey: String

    /// The container for CloudKit operations.
    private let container: CKContainer

    /// Creates a new CloudKit sync engine manager.
    ///
    /// - Parameters:
    ///   - configuration: The CloudKit configuration
    ///   - delegate: The actor that handles sync events and provides records
    ///   - stateKey: UserDefaults key for persisting sync state across launches
    ///     (default: `"com.arcstorage.cloudkit.syncState"`)
    public init(configuration: CloudKitConfiguration,
                delegate: any CloudKitSyncEngineDelegate,
                stateKey: String = "com.arcstorage.cloudkit.syncState") {
        self.configuration = configuration
        self.delegate = delegate
        self.stateKey = stateKey
        container = CKContainer(identifier: configuration.containerIdentifier)
    }

    /// Starts the sync engine.
    ///
    /// Call this early in your app's lifecycle (e.g. in `scene(_:willConnectTo:options:)`).
    /// Checks iCloud account availability before creating the engine.
    ///
    /// - Throws: ``CloudKitSyncError/accountNotAvailable`` if the user is not signed in to iCloud.
    ///   ``CloudKitSyncError/engineNotStarted`` if the delegate was deallocated before `start()`.
    public func start() async throws {
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            throw CloudKitSyncError.accountNotAvailable
        }

        guard delegate != nil else {
            throw CloudKitSyncError.engineNotStarted
        }

        let database = container.privateCloudDatabase
        let stateSerialization = loadPersistedState()
        let engineDelegate = SyncEngineDelegate(manager: self)
        var engineConfig = CKSyncEngine.Configuration(database: database,
                                                      stateSerialization: stateSerialization,
                                                      delegate: engineDelegate)
        engineConfig.automaticallySync = configuration.autoSync
        syncEngine = CKSyncEngine(engineConfig)
    }

    /// Stops the sync engine and releases underlying resources.
    public func stop() {
        syncEngine = nil
    }

    /// Manually triggers sending all pending changes to CloudKit.
    ///
    /// Only needed when ``CloudKitConfiguration/autoSync`` is `false`.
    ///
    /// - Throws: ``CloudKitSyncError/engineNotStarted`` if ``start()`` has not been called.
    ///   ``CloudKitSyncError/sendFailed(underlying:)`` if the operation fails.
    public func sendChanges() async throws {
        guard let engine = syncEngine else {
            throw CloudKitSyncError.engineNotStarted
        }
        do {
            try await engine.sendChanges()
        } catch {
            throw CloudKitSyncError.sendFailed(underlying: error)
        }
    }

    /// Manually triggers fetching all pending changes from CloudKit.
    ///
    /// Only needed when ``CloudKitConfiguration/autoSync`` is `false`.
    ///
    /// - Throws: ``CloudKitSyncError/engineNotStarted`` if ``start()`` has not been called.
    ///   ``CloudKitSyncError/fetchFailed(underlying:)`` if the operation fails.
    public func fetchChanges() async throws {
        guard let engine = syncEngine else {
            throw CloudKitSyncError.engineNotStarted
        }
        do {
            try await engine.fetchChanges()
        } catch {
            throw CloudKitSyncError.fetchFailed(underlying: error)
        }
    }

    /// Enqueues local record changes to be pushed to CloudKit.
    ///
    /// Call this after modifying local data. The engine will send them on the
    /// next sync cycle (or immediately if ``CloudKitConfiguration/autoSync`` is `true`).
    ///
    /// - Parameter changes: The record zone changes to enqueue.
    public func addPendingRecordZoneChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange]) async {
        guard let engine = syncEngine else { return }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Enqueues local database-level changes (e.g. zone creation/deletion) to push to CloudKit.
    ///
    /// - Parameter changes: The database changes to enqueue.
    public func addPendingDatabaseChanges(_ changes: [CKSyncEngine.PendingDatabaseChange]) async {
        guard let engine = syncEngine else { return }
        engine.state.add(pendingDatabaseChanges: changes)
    }

    // MARK: - State Persistence

    private func loadPersistedState() -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return nil }
        return try? CKSyncEngine.State.Serialization(from: data)
    }

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? serialization.data() else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(_ event: CKSyncEngine.Event) async {
        switch event {
        case let .stateUpdate(stateUpdate):
            persistState(stateUpdate.stateSerialization)

        case let .accountChange(accountChange):
            await delegate?.syncEngine(didReceiveAccountChange: accountChange)

        case let .fetchedDatabaseChanges(databaseChanges):
            await delegate?.syncEngine(didFetchDatabaseChanges: databaseChanges)

        case let .fetchedRecordZoneChanges(zoneChanges):
            await delegate?.syncEngine(didFetchRecordZoneChanges: zoneChanges)

        case let .sentDatabaseChanges(sentChanges):
            await delegate?.syncEngine(didSendDatabaseChanges: sentChanges)

        case let .sentRecordZoneChanges(sentChanges):
            await delegate?.syncEngine(didSendRecordZoneChanges: sentChanges)

        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
             .willSendChanges, .didSendChanges, .didFetchChanges:
            break

        @unknown default:
            break
        }
    }

    fileprivate func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext) async -> CKSyncEngine
    .RecordZoneChangeBatch? {
        await delegate?.syncEngine(nextRecordZoneChangeBatchFor: context)
    }
}

// MARK: - CKSyncEngineDelegate Implementation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
private final class SyncEngineDelegate: CKSyncEngineDelegate, Sendable {
    private let manager: CloudKitSyncEngineManager

    init(manager: CloudKitSyncEngineManager) {
        self.manager = manager
    }

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) {
        Task {
            await manager.handleEvent(event)
        }
    }

    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                               syncEngine _: CKSyncEngine) async -> CKSyncEngine
    .RecordZoneChangeBatch? {
        await manager.nextRecordZoneChangeBatch(context)
    }
}

// MARK: - CloudKitSyncEngineDelegate Protocol

/// Handles sync events from ``CloudKitSyncEngineManager`` and provides records to upload.
///
/// Implement this protocol in an `actor` that owns your local data store.
/// The two methods you **must** implement are ``syncEngine(didFetchRecordZoneChanges:)``
/// (to apply downloaded changes) and ``syncEngine(nextRecordZoneChangeBatchFor:)``
/// (to provide records to upload). All other methods have empty default implementations.
///
/// ## Required Implementation
///
/// ### Providing records to upload
///
/// ``syncEngine(nextRecordZoneChangeBatchFor:)`` is called whenever the engine is
/// ready to push changes. Return a `CKSyncEngine.RecordZoneChangeBatch` built from
/// the pending changes in `context.options.scope.changes`, or `nil` when there is
/// nothing to send.
///
/// ```swift
/// func syncEngine(
///     nextRecordZoneChangeBatchFor context: CKSyncEngine.SendChangesContext
/// ) async -> CKSyncEngine.RecordZoneChangeBatch? {
///     return await CKSyncEngine.RecordZoneChangeBatch(
///         pendingChanges: context.options.scope.changes
///     ) { recordID in
///         // Look up your local model and convert it to a CKRecord
///         return myCKRecord(for: recordID)
///     }
/// }
/// ```
///
/// ### Applying downloaded records
///
/// ``syncEngine(didFetchRecordZoneChanges:)`` delivers records fetched from CloudKit.
/// Apply each record to your local store and persist any deletions.
///
/// ```swift
/// func syncEngine(
///     didFetchRecordZoneChanges changes: CKSyncEngine.Event.FetchedRecordZoneChanges
/// ) async {
///     for modification in changes.modifications {
///         apply(modification.record)
///     }
///     for deletion in changes.deletions {
///         delete(deletion.recordID)
///     }
/// }
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public protocol CloudKitSyncEngineDelegate: Actor, AnyObject {
    /// Called when the user's iCloud account status changes (e.g. sign-out).
    func syncEngine(didReceiveAccountChange change: CKSyncEngine.Event.AccountChange) async

    /// Called when CloudKit zone metadata changes are downloaded (e.g. a zone was deleted remotely).
    func syncEngine(didFetchDatabaseChanges changes: CKSyncEngine.Event.FetchedDatabaseChanges) async

    /// Called when records are downloaded from CloudKit.
    ///
    /// Apply `changes.modifications` to your local store and process `changes.deletions`.
    /// This is one of the two methods you must implement.
    func syncEngine(didFetchRecordZoneChanges changes: CKSyncEngine.Event.FetchedRecordZoneChanges) async

    /// Called after local database-level changes (zone creation/deletion) are uploaded.
    func syncEngine(didSendDatabaseChanges changes: CKSyncEngine.Event.SentDatabaseChanges) async

    /// Called after a batch of records is uploaded to CloudKit.
    func syncEngine(didSendRecordZoneChanges changes: CKSyncEngine.Event.SentRecordZoneChanges) async

    /// Provides the next batch of records to upload to CloudKit.
    ///
    /// Called repeatedly until you return `nil`. Build a `CKSyncEngine.RecordZoneChangeBatch`
    /// from `context.options.scope.changes` and map each `CKSyncEngine.PendingRecordZoneChange`
    /// to its corresponding `CKRecord`. Return `nil` when there are no more records to send.
    /// This is one of the two methods you must implement.
    func syncEngine(nextRecordZoneChangeBatchFor context: CKSyncEngine.SendChangesContext) async -> CKSyncEngine
        .RecordZoneChangeBatch?
}

// MARK: - Default Implementations

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) extension CloudKitSyncEngineDelegate {
    public func syncEngine(didReceiveAccountChange _: CKSyncEngine.Event.AccountChange) async {}
    public func syncEngine(didFetchDatabaseChanges _: CKSyncEngine.Event.FetchedDatabaseChanges) async {}
    public func syncEngine(didFetchRecordZoneChanges _: CKSyncEngine.Event.FetchedRecordZoneChanges) async {}
    public func syncEngine(didSendDatabaseChanges _: CKSyncEngine.Event.SentDatabaseChanges) async {}
    public func syncEngine(didSendRecordZoneChanges _: CKSyncEngine.Event.SentRecordZoneChanges) async {}
}

// MARK: - Errors

/// Errors thrown by ``CloudKitSyncEngineManager``.
public enum CloudKitSyncError: Error, LocalizedError, @unchecked Sendable {
    /// ``CloudKitSyncEngineManager/sendChanges()`` or ``CloudKitSyncEngineManager/fetchChanges()``
    /// was called before ``CloudKitSyncEngineManager/start()``.
    case engineNotStarted

    /// Fetching changes from CloudKit failed.
    case fetchFailed(underlying: Error)

    /// Sending changes to CloudKit failed.
    case sendFailed(underlying: Error)

    /// The user is not signed in to iCloud.
    case accountNotAvailable

    public var errorDescription: String? {
        switch self {
        case .engineNotStarted:
            "CloudKit sync engine has not been started. Call start() first."
        case let .fetchFailed(error):
            "Failed to fetch CloudKit changes: \(error.localizedDescription)"
        case let .sendFailed(error):
            "Failed to send CloudKit changes: \(error.localizedDescription)"
        case .accountNotAvailable:
            "iCloud account is not available. The user may not be signed in."
        }
    }
}

extension CloudKitSyncError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown CloudKit sync error"
    }
}

// MARK: - CKSyncEngine.State.Serialization Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) extension CKSyncEngine.State.Serialization {
    fileprivate init(from data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    fileprivate func data() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
