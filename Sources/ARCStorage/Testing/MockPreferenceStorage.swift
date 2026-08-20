import Foundation

#if DEBUG

/// Mock preference storage for testing.
///
/// Provides a testable implementation of ``PreferenceStorageProtocol`` with
/// call tracking and the ability to pre-populate mock values.
///
/// ## Example
/// ```swift
/// @Test("ViewModel reads initial value from preferences")
/// func viewModel_readsInitialValue() {
///     // Given
///     let mock = MockPreferenceStorage()
///     mock.setMockValue(true, for: AppPreferences.DarkMode.self)
///
///     // When
///     let viewModel = SettingsViewModel(preferences: mock)
///
///     // Then
///     #expect(viewModel.isDarkModeEnabled == true)
///     #expect(mock.getCallCount == 1)
///     #expect(mock.lastAccessedKey == "darkMode")
/// }
/// ```
public final class MockPreferenceStorage: PreferenceStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    // MARK: - Call Tracking

    /// Number of times `get` was called.
    public private(set) var getCallCount = 0

    /// Number of times `set` was called.
    public private(set) var setCallCount = 0

    /// Number of times `remove` was called.
    public private(set) var removeCallCount = 0

    /// Number of times `hasValue` was called.
    public private(set) var hasValueCallCount = 0

    /// The last key that was accessed (get, set, remove, or hasValue).
    public private(set) var lastAccessedKey: String?

    // MARK: - Initialization

    /// Creates a new mock preference storage.
    public init() {}

    // MARK: - PreferenceStorageProtocol

    public func get<Key: PreferenceKey>(_: Key.Type) -> Key.Value {
        lock.lock()
        defer { lock.unlock() }

        getCallCount += 1
        lastAccessedKey = Key.key

        guard let data = storage[Key.key] else {
            return Key.defaultValue
        }

        do {
            return try JSONDecoder().decode(Key.Value.self, from: data)
        } catch {
            return Key.defaultValue
        }
    }

    public func set<Key: PreferenceKey>(_ value: Key.Value, for _: Key.Type) {
        lock.lock()
        defer { lock.unlock() }

        setCallCount += 1
        lastAccessedKey = Key.key

        do {
            let data = try JSONEncoder().encode(value)
            storage[Key.key] = data
        } catch {
            // Silent failure (matches real implementation)
        }
    }

    public func remove<Key: PreferenceKey>(_: Key.Type) {
        lock.lock()
        defer { lock.unlock() }

        removeCallCount += 1
        lastAccessedKey = Key.key
        storage.removeValue(forKey: Key.key)
    }

    public func hasValue<Key: PreferenceKey>(for _: Key.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        hasValueCallCount += 1
        lastAccessedKey = Key.key
        return storage[Key.key] != nil
    }

    // MARK: - Test Helpers

    /// Sets a mock value for a preference key.
    ///
    /// Use this to pre-populate values before running tests.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The preference key type.
    public func setMockValue<Key: PreferenceKey>(_ value: Key.Value, for _: Key.Type) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try JSONEncoder().encode(value)
            storage[Key.key] = data
        } catch {
            // Silent failure
        }
    }

    /// Resets all stored values and call counts.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        storage.removeAll()
        getCallCount = 0
        setCallCount = 0
        removeCallCount = 0
        hasValueCallCount = 0
        lastAccessedKey = nil
    }
}

#endif
