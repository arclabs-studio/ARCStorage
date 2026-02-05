import Foundation
import Testing
@testable import ARCStorage

// MARK: - Test Preference Keys

private enum TestPreferences {
    struct StringValue: PreferenceKey {
        static let key = "test.string"
        static let defaultValue = "default"
    }

    struct IntValue: PreferenceKey {
        static let key = "test.int"
        static let defaultValue = 42
    }

    struct BoolValue: PreferenceKey {
        static let key = "test.bool"
        static let defaultValue = false
    }

    struct EnumValue: PreferenceKey {
        static let key = "test.enum"
        static let defaultValue = TestEnvironment.production
    }

    struct ComplexValue: PreferenceKey {
        static let key = "test.complex"
        static let defaultValue = TestConfig(name: "default", enabled: false, count: 0)
    }
}

private enum TestEnvironment: String, Codable, Sendable {
    case production
    case staging
    case development
}

private struct TestConfig: Codable, Sendable, Equatable {
    let name: String
    let enabled: Bool
    let count: Int
}

// MARK: - PreferenceStorage Tests

@Suite("PreferenceStorage Tests")
struct PreferenceStorageTests {
    // MARK: - Get Tests

    @Test("Get returns default value when not set")
    func get_returnsDefaultValue_whenNotSet() {
        // Given
        let sut = makeSUT()

        // When
        let result = sut.get(TestPreferences.StringValue.self)

        // Then
        #expect(result == "default")
    }

    @Test("Get returns stored value after set")
    func get_returnsStoredValue_afterSet() {
        // Given
        let sut = makeSUT()
        sut.set("custom value", for: TestPreferences.StringValue.self)

        // When
        let result = sut.get(TestPreferences.StringValue.self)

        // Then
        #expect(result == "custom value")
    }

    @Test("Get returns default value after remove")
    func get_returnsDefaultValue_afterRemove() {
        // Given
        let sut = makeSUT()
        sut.set("custom value", for: TestPreferences.StringValue.self)
        sut.remove(TestPreferences.StringValue.self)

        // When
        let result = sut.get(TestPreferences.StringValue.self)

        // Then
        #expect(result == "default")
    }

    // MARK: - Set Tests

    @Test("Set stores integer value")
    func set_storesIntegerValue() {
        // Given
        let sut = makeSUT()

        // When
        sut.set(100, for: TestPreferences.IntValue.self)

        // Then
        #expect(sut.get(TestPreferences.IntValue.self) == 100)
    }

    @Test("Set stores boolean value")
    func set_storesBooleanValue() {
        // Given
        let sut = makeSUT()

        // When
        sut.set(true, for: TestPreferences.BoolValue.self)

        // Then
        #expect(sut.get(TestPreferences.BoolValue.self) == true)
    }

    @Test("Set overwrites existing value")
    func set_overwritesExistingValue() {
        // Given
        let sut = makeSUT()
        sut.set("first", for: TestPreferences.StringValue.self)

        // When
        sut.set("second", for: TestPreferences.StringValue.self)

        // Then
        #expect(sut.get(TestPreferences.StringValue.self) == "second")
    }

    // MARK: - Remove Tests

    @Test("Remove clears stored value")
    func remove_clearsStoredValue() {
        // Given
        let sut = makeSUT()
        sut.set("value", for: TestPreferences.StringValue.self)

        // When
        sut.remove(TestPreferences.StringValue.self)

        // Then
        #expect(sut.hasValue(for: TestPreferences.StringValue.self) == false)
    }

    @Test("Remove does not throw when key not set")
    func remove_doesNotThrow_whenKeyNotSet() {
        // Given
        let sut = makeSUT()

        // When/Then - should not throw
        sut.remove(TestPreferences.StringValue.self)
    }

    // MARK: - HasValue Tests

    @Test("HasValue returns false when not set")
    func hasValue_returnsFalse_whenNotSet() {
        // Given
        let sut = makeSUT()

        // When
        let result = sut.hasValue(for: TestPreferences.StringValue.self)

        // Then
        #expect(result == false)
    }

    @Test("HasValue returns true after set")
    func hasValue_returnsTrue_afterSet() {
        // Given
        let sut = makeSUT()
        sut.set("value", for: TestPreferences.StringValue.self)

        // When
        let result = sut.hasValue(for: TestPreferences.StringValue.self)

        // Then
        #expect(result == true)
    }

    @Test("HasValue returns false after remove")
    func hasValue_returnsFalse_afterRemove() {
        // Given
        let sut = makeSUT()
        sut.set("value", for: TestPreferences.StringValue.self)
        sut.remove(TestPreferences.StringValue.self)

        // When
        let result = sut.hasValue(for: TestPreferences.StringValue.self)

        // Then
        #expect(result == false)
    }

    // MARK: - Enum Value Tests

    @Test("Stores and retrieves enum values")
    func storesAndRetrievesEnumValues() {
        // Given
        let sut = makeSUT()

        // When
        sut.set(TestEnvironment.staging, for: TestPreferences.EnumValue.self)

        // Then
        #expect(sut.get(TestPreferences.EnumValue.self) == .staging)
    }

    @Test("Returns default enum value when not set")
    func returnsDefaultEnumValue_whenNotSet() {
        // Given
        let sut = makeSUT()

        // When
        let result = sut.get(TestPreferences.EnumValue.self)

        // Then
        #expect(result == .production)
    }

    // MARK: - Complex Value Tests

    @Test("Stores and retrieves complex Codable values")
    func storesAndRetrievesComplexValues() {
        // Given
        let sut = makeSUT()
        let config = TestConfig(name: "custom", enabled: true, count: 42)

        // When
        sut.set(config, for: TestPreferences.ComplexValue.self)

        // Then
        #expect(sut.get(TestPreferences.ComplexValue.self) == config)
    }

    // MARK: - Key Prefix Tests

    @Test("Different key prefixes store independently")
    func differentKeyPrefixes_storeIndependently() {
        // Given
        let userDefaults = UserDefaults.standard
        let sut1 = PreferenceStorage(userDefaults: userDefaults, keyPrefix: "test.prefix1.\(UUID().uuidString)")
        let sut2 = PreferenceStorage(userDefaults: userDefaults, keyPrefix: "test.prefix2.\(UUID().uuidString)")

        // When
        sut1.set("value1", for: TestPreferences.StringValue.self)
        sut2.set("value2", for: TestPreferences.StringValue.self)

        // Then
        #expect(sut1.get(TestPreferences.StringValue.self) == "value1")
        #expect(sut2.get(TestPreferences.StringValue.self) == "value2")
    }

    // MARK: - Factory Method

    private func makeSUT() -> PreferenceStorage {
        PreferenceStorage(
            userDefaults: .standard,
            keyPrefix: "test.\(UUID().uuidString)"
        )
    }
}

// MARK: - MockPreferenceStorage Tests

@Suite("MockPreferenceStorage Tests")
struct MockPreferenceStorageTests {
    @Test("Tracks get calls")
    func tracksGetCalls() {
        // Given
        let sut = MockPreferenceStorage()

        // When
        _ = sut.get(TestPreferences.StringValue.self)
        _ = sut.get(TestPreferences.IntValue.self)

        // Then
        #expect(sut.getCallCount == 2)
        #expect(sut.lastAccessedKey == "test.int")
    }

    @Test("Tracks set calls")
    func tracksSetCalls() {
        // Given
        let sut = MockPreferenceStorage()

        // When
        sut.set("value", for: TestPreferences.StringValue.self)

        // Then
        #expect(sut.setCallCount == 1)
        #expect(sut.lastAccessedKey == "test.string")
    }

    @Test("Tracks remove calls")
    func tracksRemoveCalls() {
        // Given
        let sut = MockPreferenceStorage()

        // When
        sut.remove(TestPreferences.BoolValue.self)

        // Then
        #expect(sut.removeCallCount == 1)
        #expect(sut.lastAccessedKey == "test.bool")
    }

    @Test("Tracks hasValue calls")
    func tracksHasValueCalls() {
        // Given
        let sut = MockPreferenceStorage()

        // When
        _ = sut.hasValue(for: TestPreferences.EnumValue.self)

        // Then
        #expect(sut.hasValueCallCount == 1)
        #expect(sut.lastAccessedKey == "test.enum")
    }

    @Test("setMockValue prepopulates data")
    func setMockValue_prepopulatesData() {
        // Given
        let sut = MockPreferenceStorage()
        sut.setMockValue("preset", for: TestPreferences.StringValue.self)

        // When
        let result = sut.get(TestPreferences.StringValue.self)

        // Then
        #expect(result == "preset")
    }

    @Test("Reset clears all state")
    func reset_clearsAllState() {
        // Given
        let sut = MockPreferenceStorage()
        sut.set("value", for: TestPreferences.StringValue.self)
        _ = sut.get(TestPreferences.IntValue.self)
        sut.remove(TestPreferences.BoolValue.self)
        _ = sut.hasValue(for: TestPreferences.EnumValue.self)

        // When
        sut.reset()

        // Then
        #expect(sut.getCallCount == 0)
        #expect(sut.setCallCount == 0)
        #expect(sut.removeCallCount == 0)
        #expect(sut.hasValueCallCount == 0)
        #expect(sut.lastAccessedKey == nil)
        #expect(sut.hasValue(for: TestPreferences.StringValue.self) == false)
    }
}
