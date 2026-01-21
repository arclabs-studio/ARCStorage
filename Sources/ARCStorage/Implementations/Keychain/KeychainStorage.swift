import Foundation
import Security

/// Defines when keychain items can be accessed.
///
/// These values map directly to Apple's `kSecAttrAccessible` constants
/// and control when your app can read keychain items.
///
/// ## Security Considerations
/// Choose the most restrictive option that works for your use case:
/// - Use ``whenPasscodeSetThisDeviceOnly`` for highly sensitive data
/// - Use ``whenUnlockedThisDeviceOnly`` for sensitive data that shouldn't sync
/// - Use ``whenUnlocked`` (default) for general secure storage
///
/// ## Example
/// ```swift
/// let storage = KeychainStorage<AuthToken>(
///     service: "com.myapp.auth",
///     accessibility: .whenUnlockedThisDeviceOnly
/// )
/// ```
public enum KeychainAccessibility: Sendable {
    /// Item is only accessible when the device is unlocked.
    /// This is the default and recommended for most use cases.
    case whenUnlocked

    /// Item is only accessible when the device is unlocked.
    /// Item will not be migrated to a new device.
    case whenUnlockedThisDeviceOnly

    /// Item is accessible after first unlock until device restart.
    /// Use for background app refresh scenarios.
    case afterFirstUnlock

    /// Item is accessible after first unlock until device restart.
    /// Item will not be migrated to a new device.
    case afterFirstUnlockThisDeviceOnly

    /// Item is only accessible when a passcode is set on the device.
    /// Item will not be migrated to a new device.
    /// Most secure option - recommended for highly sensitive data.
    case whenPasscodeSetThisDeviceOnly

    /// The corresponding Security framework constant.
    var securityAttribute: CFString {
        switch self {
        case .whenUnlocked:
            kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}

/// Secure storage implementation using the iOS Keychain.
///
/// Use this for sensitive data like tokens, passwords, and credentials.
/// Data is stored encrypted in the system keychain.
///
/// ## Topics
/// ### Initialization
/// - ``init(service:accessGroup:accessibility:)``
///
/// ### Accessibility
/// - ``KeychainAccessibility``
///
/// ## Example
/// ```swift
/// struct AuthToken: Codable, Identifiable, Sendable {
///     let id: String
///     var token: String
///     var expiresAt: Date
/// }
///
/// // Default accessibility (whenUnlocked)
/// let storage = KeychainStorage<AuthToken>(service: "com.myapp.auth")
///
/// // High security - requires passcode
/// let secureStorage = KeychainStorage<AuthToken>(
///     service: "com.myapp.auth",
///     accessibility: .whenPasscodeSetThisDeviceOnly
/// )
/// try await storage.save(authToken)
/// ```
public actor KeychainStorage<T: Codable & Sendable & Identifiable>: StorageProvider
where T.ID: LosslessStringConvertible & Sendable & Hashable {
    public typealias Entity = T

    private let service: String
    private let accessGroup: String?
    private let accessibility: KeychainAccessibility
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a new keychain storage.
    ///
    /// - Parameters:
    ///   - service: The service identifier for keychain items
    ///   - accessGroup: Optional access group for shared keychain access
    ///   - accessibility: When keychain items can be accessed. Defaults to `.whenUnlocked`
    public init(
        service: String,
        accessGroup: String? = nil,
        accessibility: KeychainAccessibility = .whenUnlocked
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    public func save(_ entity: T) async throws {
        let account = String(entity.id)

        do {
            let data = try encoder.encode(entity)

            // Delete existing item first
            let deleteQuery = makeQuery(for: account)
            SecItemDelete(deleteQuery as CFDictionary)

            // Add new item
            var addQuery = makeQuery(for: account)
            addQuery[kSecValueData as String] = data

            let status = SecItemAdd(addQuery as CFDictionary, nil)

            if status != errSecSuccess {
                throw makeKeychainError(status)
            }
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }

    public func saveAll(_ entities: [T]) async throws {
        for entity in entities {
            try await save(entity)
        }
    }

    public func fetch(id: T.ID) async throws -> T? {
        let account = String(id)
        var query = makeQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw StorageError.fetchFailed(underlying: makeKeychainError(status))
        }

        guard let data = result as? Data else {
            throw StorageError.invalidData
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    public func fetchAll() async throws -> [T] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw StorageError.fetchFailed(underlying: makeKeychainError(status))
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        var entities: [T] = []

        for item in items {
            guard let data = item[kSecValueData as String] as? Data else {
                continue
            }

            do {
                let entity = try decoder.decode(T.self, from: data)
                entities.append(entity)
            } catch {
                // Skip invalid entries
                continue
            }
        }

        return entities
    }

    public func fetch(matching predicate: Predicate<T>) async throws -> [T] {
        let allEntities = try await fetchAll()
        return try allEntities.filter { entity in
            try predicate.evaluate(entity)
        }
    }

    public func delete(id: T.ID) async throws {
        let account = String(id)
        let query = makeQuery(for: account)

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            throw StorageError.entityNotFound(id: id)
        }

        guard status == errSecSuccess else {
            throw StorageError.deleteFailed(underlying: makeKeychainError(status))
        }
    }

    public func deleteAll() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        // It's okay if nothing was found
        if status != errSecSuccess, status != errSecItemNotFound {
            throw StorageError.deleteFailed(underlying: makeKeychainError(status))
        }
    }

    public func performTransaction<Result: Sendable>(
        _ block: @Sendable () async throws -> Result
    ) async throws -> Result {
        // Keychain doesn't support transactions
        do {
            return try await block()
        } catch {
            throw StorageError.transactionFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func makeQuery(for account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessibility.securityAttribute
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func makeKeychainError(_ status: OSStatus) -> NSError {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "Keychain error: \(status)"]
        )
    }
}
