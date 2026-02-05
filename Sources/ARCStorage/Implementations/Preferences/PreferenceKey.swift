import Foundation

/// Protocol for defining type-safe preference keys.
///
/// Implement this protocol to create strongly-typed keys for accessing
/// values in ``PreferenceStorage``. Each key defines its value type,
/// storage key string, and a default value returned when no value is stored.
///
/// ## Topics
/// ### Requirements
/// - ``Value``
/// - ``key``
/// - ``defaultValue``
///
/// ## Example
/// ```swift
/// enum AppPreferences {
///     struct DarkModeEnabled: PreferenceKey {
///         static let key = "app.darkMode"
///         static let defaultValue = false
///     }
///
///     struct SelectedEnvironment: PreferenceKey {
///         static let key = "app.environment"
///         static let defaultValue = Environment.production
///     }
/// }
///
/// // Usage
/// let preferences = PreferenceStorage()
/// let isDarkMode = preferences.get(AppPreferences.DarkModeEnabled.self)
/// preferences.set(true, for: AppPreferences.DarkModeEnabled.self)
/// ```
public protocol PreferenceKey {
    /// The type of value stored for this key.
    ///
    /// Must be `Codable` for JSON serialization and `Sendable` for thread safety.
    associatedtype Value: Codable & Sendable

    /// The string key used for storage.
    ///
    /// This key is combined with the storage's key prefix to form the
    /// actual UserDefaults key.
    static var key: String { get }

    /// The default value returned when no value is stored.
    ///
    /// This value is also used when stored data cannot be decoded.
    static var defaultValue: Value { get }
}
