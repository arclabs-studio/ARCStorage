import Foundation

/// Base configuration for storage providers.
///
/// Different storage providers can extend this configuration with
/// provider-specific settings.
///
/// ## Example
/// ```swift
/// let config = StorageConfiguration(
///     identifier: "com.myapp.storage",
///     isEncrypted: true
/// )
/// ```
public struct StorageConfiguration: Sendable {
    /// Unique identifier for this storage instance.
    public let identifier: String

    /// Whether data should be encrypted at rest.
    public let isEncrypted: Bool

    /// Whether autosave is enabled.
    public let isAutosaveEnabled: Bool

    /// Creates a new storage configuration.
    ///
    /// - Parameters:
    ///   - identifier: Unique identifier
    ///   - isEncrypted: Enable encryption
    ///   - isAutosaveEnabled: Enable autosave
    public init(
        identifier: String,
        isEncrypted: Bool = false,
        isAutosaveEnabled: Bool = true
    ) {
        self.identifier = identifier
        self.isEncrypted = isEncrypted
        self.isAutosaveEnabled = isAutosaveEnabled
    }
}
