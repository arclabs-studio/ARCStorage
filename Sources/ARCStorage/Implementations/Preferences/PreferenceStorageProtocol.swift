import Foundation

/// Protocol defining the interface for preference storage.
///
/// Use this protocol for dependency injection to enable testing with
/// ``MockPreferenceStorage``. All operations are synchronous, making
/// this suitable for use in initializers and synchronous contexts.
///
/// ## Topics
/// ### Reading Values
/// - ``get(_:)``
/// - ``hasValue(for:)``
///
/// ### Writing Values
/// - ``set(_:for:)``
/// - ``remove(_:)``
///
/// ## Example
/// ```swift
/// final class SettingsManager {
///     private let preferences: PreferenceStorageProtocol
///
///     init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
///         self.preferences = preferences
///     }
///
///     var isDarkModeEnabled: Bool {
///         preferences.get(AppPreferences.DarkMode.self)
///     }
/// }
///
/// // In tests
/// let mockPreferences = MockPreferenceStorage()
/// mockPreferences.setMockValue(true, for: AppPreferences.DarkMode.self)
/// let manager = SettingsManager(preferences: mockPreferences)
/// ```
public protocol PreferenceStorageProtocol: Sendable {
    /// Retrieves the value for the specified preference key.
    ///
    /// Returns the stored value if present and decodable, otherwise returns
    /// the key's default value.
    ///
    /// - Parameter key: The preference key type to retrieve.
    /// - Returns: The stored value or the key's default value.
    func get<Key: PreferenceKey>(_ key: Key.Type) -> Key.Value

    /// Stores a value for the specified preference key.
    ///
    /// The value is JSON-encoded before storage.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The preference key type for storage.
    func set<Key: PreferenceKey>(_ value: Key.Value, for key: Key.Type)

    /// Removes the stored value for the specified preference key.
    ///
    /// After removal, subsequent calls to ``get(_:)`` will return
    /// the key's default value.
    ///
    /// - Parameter key: The preference key type to remove.
    func remove(_ key: (some PreferenceKey).Type)

    /// Checks whether a value exists for the specified preference key.
    ///
    /// - Parameter key: The preference key type to check.
    /// - Returns: `true` if a value is stored, `false` otherwise.
    func hasValue(for key: (some PreferenceKey).Type) -> Bool
}
