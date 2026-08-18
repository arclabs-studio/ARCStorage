import CloudKit
import Foundation
@preconcurrency import SwiftData

/// Configuration for SwiftData-based storage.
///
/// This configuration sets up SwiftData with optional CloudKit sync,
/// autosave, and custom model configurations.
///
/// ## Multiple Containers
///
/// When an app uses more than one `ModelContainer` (e.g. a CloudKit container plus a
/// local-only photo container), each must write to a **distinct store file**.
/// Pass a unique `storeName` to avoid both containers defaulting to `default.store`:
///
/// ```swift
/// // CloudKit-enabled restaurant store  →  default.store
/// let restaurantConfig = SwiftDataConfiguration(
///     schema: Schema([RestaurantModel.self]),
///     cloudKit: .enabled(containerIdentifier: "iCloud.com.example.app")
/// )
///
/// // Local-only photo store  →  arc-photos.store
/// let photoConfig = SwiftDataConfiguration(
///     schema: Schema([ARCPhoto.self]),
///     storeName: "arc-photos"
/// )
/// ```
///
/// ## CloudKit Requirements
///
/// When `cloudKit` is set to ``CloudKitOption/enabled(containerIdentifier:)``,
/// your models must follow specific requirements for CloudKit compatibility:
///
/// ### Property Requirements
///
/// **All properties must be optional OR have default values.** CloudKit sync can create
/// partial objects during sync conflicts, so every property needs a valid default state.
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     var id: UUID = UUID()     // Has default value
///     var name: String = ""     // Has default value
///     var rating: Double?       // Optional
///     var cuisineType: String?  // Optional
/// }
/// ```
///
/// ### Relationship Requirements
///
/// **All relationships must be optional.** CloudKit cannot guarantee that related
/// objects will sync simultaneously, so relationships must handle missing references.
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     var id: UUID = UUID()
///     var name: String = ""
///
///     // Optional relationship - required for CloudKit
///     @Relationship(deleteRule: .cascade)
///     var reviews: [Review]?
///
///     // Optional inverse relationship
///     var owner: Owner?
/// }
/// ```
///
/// ### Unique Constraints
///
/// > Important: `@Attribute(.unique)` is **not compatible** with CloudKit sync.
/// > CloudKit uses its own record identifiers and unique constraints cause sync
/// > failures. Only use `@Attribute(.unique)` for local-only models.
/// > If you need uniqueness with CloudKit, enforce it in your application logic.
///
/// ## Topics
/// ### Creating Configuration
/// - ``init(schema:storeName:cloudKit:allowsSave:)``
/// - ``makeContainer()``
/// - ``makeContainerWithFallback()``
/// - ``makeContainerReportingMode()``
///
/// ## Example
///
/// ### Basic Setup
/// ```swift
/// let config = SwiftDataConfiguration(
///     schema: Schema([Restaurant.self, Review.self])
/// )
/// let container = try config.makeContainer()
/// ```
///
/// ### CloudKit Setup
/// ```swift
/// let config = SwiftDataConfiguration(
///     schema: Schema([Restaurant.self, Review.self]),
///     cloudKit: .enabled(containerIdentifier: "iCloud.com.myapp")
/// )
/// let container = try await config.makeContainerWithFallback()
/// ```
public struct SwiftDataConfiguration: Sendable {
    /// The schema defining the models to persist.
    public let schema: Schema

    /// The optional store file name (e.g. `"arc-photos"` → `arc-photos.store`).
    ///
    /// `nil` means the system default (`default.store`) is used.
    public let storeName: String?

    /// The CloudKit sync option.
    public let cloudKit: CloudKitOption

    /// Whether manual saves are allowed.
    public let allowsSave: Bool

    /// The model configuration for SwiftData.
    public let modelConfiguration: ModelConfiguration

    /// Creates a new SwiftData configuration.
    ///
    /// - Parameters:
    ///   - schema: The schema containing model definitions
    ///   - storeName: Optional store file name (e.g. `"arc-photos"` → `arc-photos.store`).
    ///     When omitted the system default (`default.store`) is used. Provide a unique name
    ///     when you create more than one `ModelContainer` in the same app to prevent both
    ///     containers from opening the same backing file with different schemas.
    ///   - cloudKit: CloudKit sync option (default: `.disabled`)
    ///   - allowsSave: Allow manual save operations (default: `true`)
    public init(schema: Schema,
                storeName: String? = nil,
                cloudKit: CloudKitOption = .disabled,
                allowsSave: Bool = true) {
        self.schema = schema
        self.storeName = storeName
        self.cloudKit = cloudKit
        self.allowsSave = allowsSave

        var cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
        if case let .enabled(containerIdentifier) = cloudKit {
            cloudKitDatabase = .private(containerIdentifier)
        }

        if let storeName {
            modelConfiguration = ModelConfiguration(storeName,
                                                    schema: schema,
                                                    allowsSave: allowsSave,
                                                    cloudKitDatabase: cloudKitDatabase)
        } else {
            modelConfiguration = ModelConfiguration(allowsSave: allowsSave,
                                                    cloudKitDatabase: cloudKitDatabase)
        }
    }

    /// Creates a model container from this configuration.
    ///
    /// - Returns: A configured model container
    /// - Throws: Error if container creation fails
    @MainActor public func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    /// Creates a model container with automatic fallback for CloudKit.
    ///
    /// When CloudKit is enabled, this method checks the iCloud account status first:
    /// - If the account is available, creates a CloudKit-enabled container.
    /// - If the account is unavailable, falls back to a local-only container.
    /// - If CloudKit is disabled, delegates to ``makeContainer()``.
    ///
    /// Use this method in your app's initialization to gracefully handle users
    /// who are not signed in to iCloud.
    ///
    /// - Returns: A configured model container
    /// - Throws: Error if container creation fails
    @MainActor public func makeContainerWithFallback() async throws -> ModelContainer {
        try await makeContainerReportingMode().container
    }

    /// Creates a model container with automatic CloudKit fallback, reporting which mode was used.
    ///
    /// Behaves exactly like ``makeContainerWithFallback()`` but also returns a ``ContainerMode``
    /// so the app can tell whether CloudKit sync is actually active. Use it to surface a
    /// "not signed in to iCloud" banner instead of silently running local-only.
    ///
    /// The fallback container uses the **same backing store file** as the CloudKit configuration,
    /// so a named ``storeName`` is preserved and no data becomes invisible.
    ///
    /// - Returns: The container plus the mode it was created in
    /// - Throws: Error if container creation fails
    ///
    /// ## Example
    /// ```swift
    /// let result = try await config.makeContainerReportingMode()
    /// if case let .localFallback(reason) = result.mode {
    ///     showSyncWarning(reason)
    /// }
    /// ```
    @MainActor public func makeContainerReportingMode() async throws -> ContainerResult {
        switch cloudKit {
        case .disabled:
            return try ContainerResult(container: makeContainer(), mode: .localOnly)

        case let .enabled(containerIdentifier):
            let container = CKContainer(identifier: containerIdentifier)
            let accountStatus: CKAccountStatus
            do {
                accountStatus = try await container.accountStatus()
            } catch {
                return try makeFallbackResult(reason: .error(error.localizedDescription))
            }

            switch SyncState.from(accountStatus) {
            case .available, .syncing:
                return try ContainerResult(container: makeContainer(), mode: .cloudKit)
            case let .unavailable(reason):
                return try makeFallbackResult(reason: reason)
            }
        }
    }

    // MARK: - Internal

    /// The local-only equivalent of ``modelConfiguration`` — same backing store file, no CloudKit.
    func localOnlyConfiguration() -> ModelConfiguration {
        ModelConfiguration(storeName,
                           schema: schema,
                           url: modelConfiguration.url,
                           allowsSave: allowsSave,
                           cloudKitDatabase: .none)
    }

    // MARK: - Private

    @MainActor private func makeFallbackResult(reason: UnavailableReason) throws -> ContainerResult {
        try ContainerResult(container: makeLocalOnlyContainer(), mode: .localFallback(reason: reason))
    }

    @MainActor private func makeLocalOnlyContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [localOnlyConfiguration()])
    }
}
