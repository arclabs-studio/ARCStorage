import Foundation
import SwiftData

/// Configuration for SwiftData-based storage.
///
/// This configuration sets up SwiftData with support for CloudKit sync,
/// autosave, and custom model configurations.
///
/// ## Topics
/// ### Creating Configuration
/// - ``init(schema:isCloudKitEnabled:allowsSave:)``
/// - ``makeContainer()``
///
/// ## Example
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
