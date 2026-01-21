import CloudKit
import Foundation

/// A wrapper around `CKSyncEngine` that manages CloudKit synchronization.
///
/// This class provides a simplified interface for syncing local data with CloudKit,
/// handling push notifications, conflict resolution, and state persistence.
///
/// ## Topics
/// ### Initialization
/// - ``init(configuration:delegate:)``
///
/// ### Sync Operations
/// - ``sendChanges()``
/// - ``fetchChanges()``
///
/// ## Example
/// ```swift
/// let config = CloudKitConfiguration(
///     containerIdentifier: "iCloud.com.myapp.container"
/// )
/// let engine = try await CloudKitSyncEngineManager(
///     configuration: config,
///     delegate: myDelegate
/// )
/// try await engine.sendChanges()
/// ```
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public actor CloudKitSyncEngineManager {
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
    ///   - delegate: The delegate for handling sync events
    ///   - stateKey: Key for persisting sync state in UserDefaults
    public init(
        configuration: CloudKitConfiguration,
        delegate: any CloudKitSyncEngineDelegate,
        stateKey: String = "com.arcstorage.cloudkit.syncState"
    ) {
        self.configuration = configuration
        self.delegate = delegate
        self.stateKey = stateKey
        container = CKContainer(identifier: configuration.containerIdentifier)
    }

    /// Starts the sync engine.
    ///
    /// Call this method early in your app's lifecycle to begin syncing.
    public func start() async throws {
        let database = container.privateCloudDatabase

        // Load persisted state if available
        let stateSerialization = loadPersistedState()

        // Create the sync engine configuration
        let engineDelegate = SyncEngineDelegate(manager: self)
        var engineConfig = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: stateSerialization,
            delegate: engineDelegate
        )

        // Configure automatic sync based on our configuration
        engineConfig.automaticallySync = configuration.autoSync

        // Create and store the sync engine
        syncEngine = CKSyncEngine(engineConfig)
    }

    /// Stops the sync engine.
    public func stop() {
        syncEngine = nil
    }

    /// Manually triggers sending pending changes to CloudKit.
    public func sendChanges() async throws {
        guard let engine = syncEngine else {
            throw CloudKitSyncError.engineNotStarted
        }

        try await engine.sendChanges()
    }

    /// Manually triggers fetching changes from CloudKit.
    public func fetchChanges() async throws {
        guard let engine = syncEngine else {
            throw CloudKitSyncError.engineNotStarted
        }

        try await engine.fetchChanges()
    }

    /// Adds pending record changes to be sent to CloudKit.
    ///
    /// - Parameter changes: The record zone changes to send
    public func addPendingRecordZoneChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange]) async {
        guard let engine = syncEngine else { return }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    /// Adds pending database changes to be sent to CloudKit.
    ///
    /// - Parameter changes: The database changes to send
    public func addPendingDatabaseChanges(_ changes: [CKSyncEngine.PendingDatabaseChange]) async {
        guard let engine = syncEngine else { return }
        engine.state.add(pendingDatabaseChanges: changes)
    }

    // MARK: - State Persistence

    private func loadPersistedState() -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else {
            return nil
        }

        do {
            return try CKSyncEngine.State.Serialization(from: data)
        } catch {
            return nil
        }
    }

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        do {
            let data = try serialization.data()
            UserDefaults.standard.set(data, forKey: stateKey)
        } catch {
            // Log error but don't throw - state persistence is best-effort
        }
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
            // Progress events - could be used for UI updates
            break

        @unknown default:
            break
        }
    }

    fileprivate func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await delegate?.syncEngine(nextRecordZoneChangeBatchFor: context)
    }
}

// MARK: - CKSyncEngineDelegate Implementation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
private final class SyncEngineDelegate: CKSyncEngineDelegate, @unchecked Sendable {
    private let manager: CloudKitSyncEngineManager

    init(manager: CloudKitSyncEngineManager) {
        self.manager = manager
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) {
        Task {
            await manager.handleEvent(event)
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine _: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await manager.nextRecordZoneChangeBatch(context)
    }
}

// MARK: - CloudKitSyncEngineDelegate Protocol

/// Protocol for handling CloudKit sync events.
///
/// Implement this protocol to respond to sync events and provide
/// records to be synced.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
// swiftlint:disable:next class_delegate_protocol
public protocol CloudKitSyncEngineDelegate: Actor {
    /// Called when account status changes.
    func syncEngine(didReceiveAccountChange change: CKSyncEngine.Event.AccountChange) async

    /// Called when database changes are fetched from CloudKit.
    func syncEngine(didFetchDatabaseChanges changes: CKSyncEngine.Event.FetchedDatabaseChanges) async

    /// Called when record zone changes are fetched from CloudKit.
    func syncEngine(didFetchRecordZoneChanges changes: CKSyncEngine.Event.FetchedRecordZoneChanges) async

    /// Called when database changes have been sent to CloudKit.
    func syncEngine(didSendDatabaseChanges changes: CKSyncEngine.Event.SentDatabaseChanges) async

    /// Called when record zone changes have been sent to CloudKit.
    func syncEngine(didSendRecordZoneChanges changes: CKSyncEngine.Event.SentRecordZoneChanges) async

    /// Provides the next batch of record zone changes to send.
    func syncEngine(
        nextRecordZoneChangeBatchFor context: CKSyncEngine.SendChangesContext
    ) async -> CKSyncEngine.RecordZoneChangeBatch?
}

// MARK: - Default Implementations

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension CloudKitSyncEngineDelegate {
    public func syncEngine(didReceiveAccountChange _: CKSyncEngine.Event.AccountChange) async {}
    public func syncEngine(didFetchDatabaseChanges _: CKSyncEngine.Event.FetchedDatabaseChanges) async {}
    public func syncEngine(didSendDatabaseChanges _: CKSyncEngine.Event.SentDatabaseChanges) async {}
}

// MARK: - Errors

/// Errors that can occur during CloudKit sync operations.
public enum CloudKitSyncError: Error, LocalizedError, Sendable {
    /// The sync engine has not been started.
    case engineNotStarted

    /// Failed to fetch changes from CloudKit.
    case fetchFailed(underlying: Error)

    /// Failed to send changes to CloudKit.
    case sendFailed(underlying: Error)

    /// Account is not available.
    case accountNotAvailable

    public var errorDescription: String? {
        switch self {
        case .engineNotStarted:
            "CloudKit sync engine has not been started"
        case let .fetchFailed(error):
            "Failed to fetch changes: \(error.localizedDescription)"
        case let .sendFailed(error):
            "Failed to send changes: \(error.localizedDescription)"
        case .accountNotAvailable:
            "iCloud account is not available"
        }
    }
}

// MARK: - CKSyncEngine.State.Serialization Extension

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension CKSyncEngine.State.Serialization {
    fileprivate init(from data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    fileprivate func data() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
