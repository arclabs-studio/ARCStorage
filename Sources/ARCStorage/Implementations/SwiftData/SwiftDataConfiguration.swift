import Foundation
@preconcurrency import SwiftData

/// Configuration for SwiftData-based storage.
///
/// This configuration sets up SwiftData with support for CloudKit sync,
/// autosave, and custom model configurations.
///
/// ## CloudKit Requirements
///
/// When `isCloudKitEnabled` is `true`, your models must follow specific requirements
/// to ensure CloudKit compatibility:
///
/// ### Property Requirements
///
/// **All properties must be optional OR have default values.** CloudKit sync can create
/// partial objects during sync conflicts, so every property needs a valid default state.
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()     // ✅ Has default value
///     var name: String = ""     // ✅ Has default value
///     var rating: Double?       // ✅ Optional
///     var cuisineType: String?  // ✅ Optional
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
///     // ✅ Optional relationship - required for CloudKit
///     @Relationship(deleteRule: .cascade)
///     var reviews: [Review]?
///
///     // ✅ Optional inverse relationship
///     var owner: Owner?
/// }
/// ```
///
/// ### Index Requirements
///
/// Use `@Attribute(.unique)` on your `id` property to create an index for faster lookups:
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)  // Creates database index
///     var id: UUID = UUID()
///     // ...
/// }
/// ```
///
/// ## Topics
/// ### Creating Configuration
/// - ``init(schema:isCloudKitEnabled:allowsSave:)``
/// - ``makeContainer()``
///
/// ## Example
///
/// ### Basic Setup
/// ```swift
/// let config = SwiftDataConfiguration(
///     schema: Schema([Restaurant.self, Review.self]),
///     isCloudKitEnabled: false
/// )
/// let container = try config.makeContainer()
/// ```
///
/// ### CloudKit Setup
/// ```swift
/// let config = SwiftDataConfiguration(
///     schema: Schema([Restaurant.self, Review.self]),
///     isCloudKitEnabled: true
/// )
/// let container = try config.makeContainer()
/// ```
public struct SwiftDataConfiguration: Sendable {
    /// The schema defining the models to persist.
    public let schema: Schema

    /// Whether CloudKit sync is enabled.
    public let isCloudKitEnabled: Bool

    /// Whether manual saves are allowed.
    public let allowsSave: Bool

    /// The model configuration for SwiftData.
    public let modelConfiguration: ModelConfiguration

    /// Creates a new SwiftData configuration.
    ///
    /// - Parameters:
    ///   - schema: The schema containing model definitions
    ///   - isCloudKitEnabled: Enable CloudKit synchronization
    ///   - allowsSave: Allow manual save operations
    public init(
        schema: Schema,
        isCloudKitEnabled: Bool = false,
        allowsSave: Bool = true
    ) {
        self.schema = schema
        self.isCloudKitEnabled = isCloudKitEnabled
        self.allowsSave = allowsSave
        modelConfiguration = ModelConfiguration(
            allowsSave: allowsSave,
            cloudKitDatabase: isCloudKitEnabled ? .automatic : .none
        )
    }

    /// Creates a model container from this configuration.
    ///
    /// - Returns: A configured model container
    /// - Throws: Error if container creation fails
    public func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}
