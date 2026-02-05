import Foundation

/// Synchronous key-value storage for simple preferences.
///
/// `PreferenceStorage` provides a type-safe, synchronous API for storing
/// simple configuration values. Unlike ``UserDefaultsStorage`` which is
/// async and entity-centric, this is designed for simple key-value access
/// in synchronous contexts like `init()`.
///
/// ## Topics
/// ### Initialization
/// - ``init(userDefaults:keyPrefix:)``
///
/// ### Thread Safety
///
/// `PreferenceStorage` is `Sendable` and thread-safe. The underlying
/// `UserDefaults` is thread-safe, and the struct itself is value-typed.
///
/// ## Example
/// ```swift
/// // Define preference keys
/// enum AppPreferences {
///     struct DarkModeEnabled: PreferenceKey {
///         static let key = "darkMode"
///         static let defaultValue = false
///     }
///
///     struct OnboardingCompleted: PreferenceKey {
///         static let key = "onboardingCompleted"
///         static let defaultValue = false
///     }
/// }
///
/// // Use in initializer (synchronous!)
/// final class AppCoordinator {
///     private let preferences: PreferenceStorageProtocol
///
///     init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
///         self.preferences = preferences
///
///         // Works synchronously in init
///         if !preferences.get(AppPreferences.OnboardingCompleted.self) {
///             showOnboarding()
///         }
///     }
/// }
/// ```
public struct PreferenceStorage: PreferenceStorageProtocol, @unchecked Sendable {
    // UserDefaults is thread-safe but doesn't formally conform to Sendable.
    // Using @unchecked Sendable is safe because:
    // 1. UserDefaults is documented as thread-safe by Apple
    // 2. JSONEncoder/JSONDecoder are value types but contain non-Sendable internal state
    // 3. All operations are atomic (single read/write calls)
    private let userDefaults: UserDefaults
    private let keyPrefix: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a new preference storage.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///   - keyPrefix: Prefix for all keys to avoid collisions. Defaults to `"ARCPrefs"`.
    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "ARCPrefs"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func get<Key: PreferenceKey>(_: Key.Type) -> Key.Value {
        let storageKey = makeKey(for: Key.key)

        guard let data = userDefaults.data(forKey: storageKey) else {
            return Key.defaultValue
        }

        do {
            return try decoder.decode(Key.Value.self, from: data)
        } catch {
            // Return default on decode error (matches UserDefaults behavior)
            return Key.defaultValue
        }
    }

    public func set<Key: PreferenceKey>(_ value: Key.Value, for _: Key.Type) {
        let storageKey = makeKey(for: Key.key)

        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Silent failure on encode error (matches UserDefaults behavior)
        }
    }

    public func remove<Key: PreferenceKey>(_: Key.Type) {
        let storageKey = makeKey(for: Key.key)
        userDefaults.removeObject(forKey: storageKey)
    }

    public func hasValue<Key: PreferenceKey>(for _: Key.Type) -> Bool {
        let storageKey = makeKey(for: Key.key)
        return userDefaults.object(forKey: storageKey) != nil
    }

    // MARK: - Private Methods

    private func makeKey(for key: String) -> String {
        "\(keyPrefix).\(key)"
    }
}
