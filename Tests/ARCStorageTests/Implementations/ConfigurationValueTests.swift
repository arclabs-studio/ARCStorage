import Foundation
import Testing
@testable import ARCStorage

@Suite("ConfigurationValue Tests")
struct ConfigurationValueTests {
    // MARK: - Helpers

    /// Builds a throwaway on-disk `.bundle` whose `Info.plist` contains the
    /// supplied keys, so `ConfigurationValue.string` can be exercised against a
    /// controlled bundle without touching the test runner's own `Info.plist`.
    private func makeBundle(infoPlist: [String: String]) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigurationValueTests-\(UUID().uuidString).bundle")
        let contents = root.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
        // macOS bundles read Contents/Info.plist; other platforms read the flat root.
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        try data.write(to: root.appendingPathComponent("Info.plist"))

        return try #require(Bundle(url: root))
    }

    // MARK: - string(_:bundle:)

    @Test("string returns the value for a key present in the bundle's Info.plist")
    func string_returnsValue_whenKeyPresent() throws {
        // Given
        let bundle = try makeBundle(infoPlist: ["RC_API_KEY": "appl_test_key_123"])

        // When
        let value = ConfigurationValue.string("RC_API_KEY", bundle: bundle)

        // Then
        #expect(value == "appl_test_key_123")
    }

    @Test("string returns nil when the key maps to an empty string") func string_returnsNil_whenValueEmpty() throws {
        // Given
        let bundle = try makeBundle(infoPlist: ["RC_API_KEY": ""])

        // When
        let value = ConfigurationValue.string("RC_API_KEY", bundle: bundle)

        // Then
        #expect(value == nil)
    }

    @Test("string returns nil for a key that is absent from the Info.plist")
    func string_returnsNil_whenKeyMissing() throws {
        // Given
        let bundle = try makeBundle(infoPlist: ["OtherKey": "value"])

        // When
        let value = ConfigurationValue.string("RC_API_KEY", bundle: bundle)

        // Then
        #expect(value == nil)
    }

    @Test("string falls back to the main bundle when no bundle is provided") func string_usesMainBundle_byDefault() {
        // Given — a key that does not exist in the test runner's main bundle.
        let key = "ARCStorage.NonexistentConfigurationKey"

        // When
        let value = ConfigurationValue.string(key)

        // Then
        #expect(value == nil)
    }

    // MARK: - deobfuscated(_:)

    @Test("deobfuscated reconstructs the original string from its UTF-8 bytes")
    func deobfuscated_roundTripsUTF8Bytes() {
        // Given
        let original = "appl_RevenueCatPublicKey-1234"
        let bytes = Array(original.utf8)

        // When
        let restored = ConfigurationValue.deobfuscated(bytes)

        // Then
        #expect(restored == original)
    }

    @Test("deobfuscated handles non-ASCII UTF-8 content") func deobfuscated_handlesUnicode() {
        // Given
        let original = "clé-secrète-€-🔐"
        let bytes = Array(original.utf8)

        // When
        let restored = ConfigurationValue.deobfuscated(bytes)

        // Then
        #expect(restored == original)
    }

    @Test("deobfuscated returns nil for bytes that are not valid UTF-8") func deobfuscated_returnsNil_forInvalidUTF8() {
        // Given — 0xFF / 0xFE are never valid UTF-8 lead bytes.
        let bytes: [UInt8] = [0xFF, 0xFE, 0xFF]

        // When
        let restored = ConfigurationValue.deobfuscated(bytes)

        // Then
        #expect(restored == nil)
    }

    @Test("deobfuscated returns an empty string for an empty byte array")
    func deobfuscated_returnsEmptyString_forEmptyInput() {
        // Given
        let bytes: [UInt8] = []

        // When
        let restored = ConfigurationValue.deobfuscated(bytes)

        // Then
        #expect(restored?.isEmpty == true)
    }
}
