import Foundation
import Security
import Testing

/// Detects whether the test process can use the Keychain.
///
/// SwiftPM test bundles on the iOS Simulator run without a host app, so they carry no
/// keychain entitlement and every `SecItem*` call fails with `errSecMissingEntitlement`
/// (-34018). Keychain suites are disabled in that environment and still run on macOS.
enum KeychainAvailability {
    static let isAvailable: Bool = {
        let service = "com.arclabs.tests.keychain-probe"
        let account = UUID().uuidString
        let addQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrService as String: service,
                                       kSecAttrAccount as String: account,
                                       kSecValueData as String: Data([0])]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                              kSecAttrService as String: service,
                                              kSecAttrAccount as String: account]
            _ = SecItemDelete(deleteQuery as CFDictionary)
        }
        return status != errSecMissingEntitlement
    }()

    static let unavailableReason: Comment =
        "Keychain needs an entitlement that SwiftPM test bundles lack on the iOS Simulator (-34018)"
}
