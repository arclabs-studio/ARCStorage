import Foundation
import SwiftData

/// Defines a migration from one schema version to another.
///
/// Migration plans specify how to transform data when the model schema changes.
///
/// ## Example
/// ```swift
/// let migration = MigrationPlan(
///     sourceVersion: "1.0",
///     destinationVersion: "2.0",
///     transform: { context in
///         // Migration logic
///     }
/// )
/// ```
public struct MigrationPlan: Sendable {
    /// Source schema version.
    public let sourceVersion: String

    /// Destination schema version.
    public let destinationVersion: String

    /// Transformation logic.
    public let transform: @Sendable (MigrationContext) async throws -> Void

    /// Creates a new migration plan.
    ///
    /// - Parameters:
    ///   - sourceVersion: Starting version
    ///   - destinationVersion: Target version
    ///   - transform: Migration transformation
    public init(
        sourceVersion: String,
        destinationVersion: String,
        transform: @escaping @Sendable (MigrationContext) async throws -> Void
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        self.transform = transform
    }
}

/// Context provided during migration.
public struct MigrationContext: Sendable {
    /// Source schema version.
    public let sourceVersion: String

    /// Destination schema version.
    public let destinationVersion: String

    /// Creates a new migration context.
    public init(sourceVersion: String, destinationVersion: String) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
    }
}

/// Manages a series of migrations.
public actor MigrationManager {
    private var plans: [MigrationPlan] = []

    /// Creates a new migration manager.
    public init() {}

    /// Adds a migration plan.
    ///
    /// - Parameter plan: The migration plan to add
    public func addPlan(_ plan: MigrationPlan) {
        plans.append(plan)
    }

    /// Executes migrations from source to destination version.
    ///
    /// - Parameters:
    ///   - sourceVersion: Starting version
    ///   - destinationVersion: Target version
    public func migrate(from sourceVersion: String, to destinationVersion: String) async throws {
        // Find migration path
        var currentVersion = sourceVersion
        let applicablePlans = plans.filter { $0.sourceVersion == currentVersion }

        for plan in applicablePlans where plan.destinationVersion == destinationVersion {
            let context = MigrationContext(
                sourceVersion: plan.sourceVersion,
                destinationVersion: plan.destinationVersion
            )

            try await plan.transform(context)
            currentVersion = plan.destinationVersion
        }

        guard currentVersion == destinationVersion else {
            throw MigrationError.noMigrationPath(
                from: sourceVersion,
                to: destinationVersion
            )
        }
    }
}

/// Errors that can occur during migration.
public enum MigrationError: Error, Sendable {
    /// No migration path exists between versions.
    case noMigrationPath(from: String, to: String)

    /// Migration failed.
    case migrationFailed(underlying: Error)
}

extension MigrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .noMigrationPath(from, to):
            return "No migration path from version \(from) to \(to)"
        case let .migrationFailed(error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}
