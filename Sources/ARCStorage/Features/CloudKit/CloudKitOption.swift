import Foundation

/// Configures optional CloudKit synchronization for SwiftData.
///
/// Use this enum when creating a ``SwiftDataConfiguration`` to opt in
/// to automatic cross-device sync via SwiftData's built-in CloudKit support.
///
/// ## Example
/// ```swift
/// // Local-only (default)
/// let config = SwiftDataConfiguration(schema: schema)
///
/// // CloudKit-enabled
/// let config = SwiftDataConfiguration(
///     schema: schema,
///     cloudKit: .enabled(containerIdentifier: "iCloud.com.myapp")
/// )
/// ```
public enum CloudKitOption: Sendable, Equatable {
    /// CloudKit sync is disabled. Data is stored locally only.
    case disabled

    /// CloudKit sync is enabled using the specified container.
    ///
    /// - Parameter containerIdentifier: The CloudKit container identifier
    ///   (e.g., `"iCloud.com.mycompany.myapp"`).
    case enabled(containerIdentifier: String)
}
