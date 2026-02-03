import Foundation
import SwiftData

/// Documentation and utilities for SwiftData schema migrations using `VersionedSchema`.
///
/// SwiftData provides built-in support for schema migrations through `VersionedSchema` and
/// `SchemaMigrationPlan`. This file provides guidance and helper utilities for implementing
/// migrations in your app.
///
/// ## Overview
///
/// SwiftData migrations follow a three-step pattern:
/// 1. Define versioned schemas as static types
/// 2. Create a migration plan that specifies how to migrate between versions
/// 3. Pass the migration plan to your `ModelContainer` configuration
///
/// ## Lightweight vs Custom Migrations
///
/// SwiftData supports two types of migrations:
///
/// ### Lightweight Migrations (Automatic)
/// Handled automatically when changes are simple:
/// - Adding new properties with default values
/// - Removing properties
/// - Renaming properties (with `@Attribute(originalName:)`)
/// - Adding or removing optional relationships
///
/// ### Custom Migrations
/// Required for complex changes:
/// - Data transformations (e.g., splitting a name into first/last)
/// - Changing property types
/// - Complex relationship changes
///
/// ## Example: Complete Migration Setup
///
/// ```swift
/// // MARK: - Step 1: Define Versioned Schemas
///
/// enum RestaurantSchemaV1: VersionedSchema {
///     static var versionIdentifier = Schema.Version(1, 0, 0)
///
///     static var models: [any PersistentModel.Type] {
///         [Restaurant.self]
///     }
///
///     @Model
///     final class Restaurant {
///         var id: UUID = UUID()
///         var name: String = ""
///         var address: String = ""
///     }
/// }
///
/// enum RestaurantSchemaV2: VersionedSchema {
///     static var versionIdentifier = Schema.Version(2, 0, 0)
///
///     static var models: [any PersistentModel.Type] {
///         [Restaurant.self]
///     }
///
///     @Model
///     final class Restaurant {
///         @Attribute(.unique)
///         var id: UUID = UUID()
///         var name: String = ""
///         var streetAddress: String = ""  // Renamed from 'address'
///         var city: String = ""           // New property
///         var rating: Double = 0.0        // New property
///     }
/// }
///
/// // MARK: - Step 2: Define Migration Plan
///
/// enum RestaurantMigrationPlan: SchemaMigrationPlan {
///     static var schemas: [any VersionedSchema.Type] {
///         [RestaurantSchemaV1.self, RestaurantSchemaV2.self]
///     }
///
///     static var stages: [MigrationStage] {
///         [migrateV1toV2]
///     }
///
///     static let migrateV1toV2 = MigrationStage.custom(
///         fromVersion: RestaurantSchemaV1.self,
///         toVersion: RestaurantSchemaV2.self,
///         willMigrate: nil,
///         didMigrate: { context in
///             // Perform custom data transformations after schema update
///             let restaurants = try context.fetch(
///                 FetchDescriptor<RestaurantSchemaV2.Restaurant>()
///             )
///             for restaurant in restaurants {
///                 // Set default values for new properties
///                 if restaurant.city.isEmpty {
///                     restaurant.city = "Unknown"
///                 }
///             }
///             try context.save()
///         }
///     )
/// }
///
/// // MARK: - Step 3: Use in Configuration
///
/// let config = SwiftDataConfiguration(
///     schema: RestaurantSchemaV2.self,
///     migrationPlan: RestaurantMigrationPlan.self,
///     isCloudKitEnabled: false
/// )
/// let container = try config.makeContainer()
/// ```
///
/// ## Best Practices
///
/// 1. **Always use @Attribute(.unique) on id properties** - Enables indexing for fast lookups
/// 2. **Keep versioned schemas immutable** - Never modify existing schema versions
/// 3. **Test migrations thoroughly** - Create unit tests with sample data
/// 4. **Use willMigrate for data backup** - Save critical data before schema changes
/// 5. **Use didMigrate for data transformation** - Transform data after schema updates
///
/// ## CloudKit Considerations
///
/// When using CloudKit with migrations:
/// - Migrations only affect local data
/// - CloudKit schema changes must be done in CloudKit Dashboard
/// - New properties must be optional or have defaults for CloudKit compatibility
/// - Test thoroughly with production CloudKit containers before release
///
/// ## Topics
/// ### Migration Types
/// - ``SwiftDataMigrationStage``
///
/// ### Helper Functions
/// - ``makeVersionedContainer(schema:migrationPlan:isCloudKitEnabled:)``
public enum SwiftDataMigrationDocumentation {}

// MARK: - Migration Stage Type Alias

/// A type alias for SwiftData's `MigrationStage` for convenience.
///
/// Use this when defining custom migration stages:
/// ```swift
/// let stage = SwiftDataMigrationStage.custom(
///     fromVersion: SchemaV1.self,
///     toVersion: SchemaV2.self,
///     willMigrate: nil,
///     didMigrate: { context in
///         // Migration logic
///     }
/// )
/// ```
public typealias SwiftDataMigrationStage = MigrationStage

// MARK: - Helper Functions

/// Creates a model container with versioned schema and migration plan support.
///
/// This is a convenience function that combines schema and migration plan configuration
/// into a single call.
///
/// - Parameters:
///   - schema: The versioned schema type (must be the latest version)
///   - migrationPlan: The migration plan type that handles version upgrades
///   - isCloudKitEnabled: Whether to enable CloudKit synchronization
/// - Returns: A configured ModelContainer ready for use
/// - Throws: Error if container creation fails
///
/// ## Example
/// ```swift
/// let container = try makeVersionedContainer(
///     schema: RestaurantSchemaV2.self,
///     migrationPlan: RestaurantMigrationPlan.self,
///     isCloudKitEnabled: true
/// )
/// ```
@MainActor
public func makeVersionedContainer<S: VersionedSchema>(
    schema _: S.Type,
    migrationPlan: (some SchemaMigrationPlan).Type,
    isCloudKitEnabled: Bool = false
) throws -> ModelContainer {
    let modelConfiguration = ModelConfiguration(
        cloudKitDatabase: isCloudKitEnabled ? .automatic : .none
    )

    return try ModelContainer(
        for: Schema(versionedSchema: S.self),
        migrationPlan: migrationPlan,
        configurations: [modelConfiguration]
    )
}

// MARK: - SwiftDataConfiguration Extension

extension SwiftDataConfiguration {
    /// Creates a new SwiftData configuration with migration plan support.
    ///
    /// Use this initializer when your app requires schema migrations between versions.
    ///
    /// - Parameters:
    ///   - schema: The schema defining the models to persist
    ///   - migrationPlan: The migration plan type that handles version upgrades
    ///   - isCloudKitEnabled: Enable CloudKit synchronization
    ///   - allowsSave: Allow manual save operations
    ///
    /// ## Example
    /// ```swift
    /// let config = SwiftDataConfiguration(
    ///     schema: Schema([Restaurant.self]),
    ///     migrationPlan: RestaurantMigrationPlan.self,
    ///     isCloudKitEnabled: false
    /// )
    /// let container = try config.makeContainer(migrationPlan: RestaurantMigrationPlan.self)
    /// ```
    public init(
        schema: Schema,
        migrationPlan _: (some SchemaMigrationPlan).Type,
        isCloudKitEnabled: Bool = false,
        allowsSave: Bool = true
    ) {
        self.init(
            schema: schema,
            isCloudKitEnabled: isCloudKitEnabled,
            allowsSave: allowsSave
        )
    }

    /// Creates a model container with migration plan support.
    ///
    /// - Parameter migrationPlan: The migration plan type that handles version upgrades
    /// - Returns: A configured model container with migration support
    /// - Throws: Error if container creation fails
    ///
    /// ## Example
    /// ```swift
    /// let config = SwiftDataConfiguration(
    ///     schema: Schema([Restaurant.self]),
    ///     isCloudKitEnabled: false
    /// )
    /// let container = try config.makeContainer(
    ///     migrationPlan: RestaurantMigrationPlan.self
    /// )
    /// ```
    public func makeContainer(
        migrationPlan: (some SchemaMigrationPlan).Type
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: migrationPlan,
            configurations: [modelConfiguration]
        )
    }
}
