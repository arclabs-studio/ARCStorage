import Foundation
import os

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
public final class MockPreferenceStorage: PreferenceStorageProtocol {
    private struct State {
        var storage: [String: Data] = [:]
        var getCallCount = 0
        var setCallCount = 0
        var removeCallCount = 0
        var hasValueCallCount = 0
        var lastAccessedKey: String?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    // MARK: - Call Tracking

    /// Number of times `get` was called.
    public var getCallCount: Int {
        state.withLock { $0.getCallCount }
    }

    /// Number of times `set` was called.
    public var setCallCount: Int {
        state.withLock { $0.setCallCount }
    }

    /// Number of times `remove` was called.
    public var removeCallCount: Int {
        state.withLock { $0.removeCallCount }
    }

    /// Number of times `hasValue` was called.
    public var hasValueCallCount: Int {
        state.withLock { $0.hasValueCallCount }
    }

    /// The last key that was accessed (get, set, remove, or hasValue).
    public var lastAccessedKey: String? {
        state.withLock { $0.lastAccessedKey }
    }

    // MARK: - Initialization

    /// Creates a new mock preference storage.
    public init() {}

    // MARK: - PreferenceStorageProtocol

    public func get<Key: PreferenceKey>(_: Key.Type) -> Key.Value {
        let keyName = Key.key
        let data = state.withLock { state in
            state.getCallCount += 1
            state.lastAccessedKey = keyName
            return state.storage[keyName]
        }

        guard let data else {
            return Key.defaultValue
        }

        do {
            return try JSONDecoder().decode(Key.Value.self, from: data)
        } catch {
            return Key.defaultValue
        }
    }

    public func set<Key: PreferenceKey>(_ value: Key.Value, for _: Key.Type) {
        let keyName = Key.key
        // Silent failure on encoding errors matches the real implementation.
        let data = try? JSONEncoder().encode(value)
        state.withLock { state in
            state.setCallCount += 1
            state.lastAccessedKey = keyName
            if let data {
                state.storage[keyName] = data
            }
        }
    }

    public func remove<Key: PreferenceKey>(_: Key.Type) {
        let keyName = Key.key
        state.withLock { state in
            state.removeCallCount += 1
            state.lastAccessedKey = keyName
            _ = state.storage.removeValue(forKey: keyName)
        }
    }

    public func hasValue<Key: PreferenceKey>(for _: Key.Type) -> Bool {
        let keyName = Key.key
        return state.withLock { state in
            state.hasValueCallCount += 1
            state.lastAccessedKey = keyName
            return state.storage[keyName] != nil
        }
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
        let keyName = Key.key
        guard let data = try? JSONEncoder().encode(value) else { return }
        state.withLock { $0.storage[keyName] = data }
    }

    /// Resets all stored values and call counts.
    public func reset() {
        state.withLock { $0 = State() }
    }
}

#endif
