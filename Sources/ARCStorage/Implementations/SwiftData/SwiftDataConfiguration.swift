import CloudKit
import Foundation
@preconcurrency import SwiftData

/// Configuration for SwiftData-based storage.
///
/// This configuration sets up SwiftData with optional CloudKit sync,
/// autosave, and custom model configurations.
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
/// - ``init(schema:cloudKit:allowsSave:)``
/// - ``makeContainer()``
/// - ``makeContainerWithFallback()``
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
    ///   - cloudKit: CloudKit sync option (default: `.disabled`)
    ///   - allowsSave: Allow manual save operations (default: `true`)
    public init(
        schema: Schema,
        cloudKit: CloudKitOption = .disabled,
        allowsSave: Bool = true
    ) {
        self.schema = schema
        self.cloudKit = cloudKit
        self.allowsSave = allowsSave

        var cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
        if case let .enabled(containerIdentifier) = cloudKit {
            cloudKitDatabase = .private(containerIdentifier)
        }

        modelConfiguration = ModelConfiguration(allowsSave: allowsSave, cloudKitDatabase: cloudKitDatabase)
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
        switch cloudKit {
        case .disabled:
            return try makeContainer()

        case let .enabled(containerIdentifier):
            let container = CKContainer(identifier: containerIdentifier)
            let accountStatus: CKAccountStatus
            do {
                accountStatus = try await container.accountStatus()
            } catch {
                return try makeLocalOnlyContainer()
            }

            switch accountStatus {
            case .available:
                return try makeContainer()
            default:
                return try makeLocalOnlyContainer()
            }
        }
    }

    // MARK: - Private

    @MainActor private func makeLocalOnlyContainer() throws -> ModelContainer {
        let localConfig = ModelConfiguration(allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [localConfig])
    }
}
