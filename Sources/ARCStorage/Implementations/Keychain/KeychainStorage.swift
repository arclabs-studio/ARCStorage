import Security
import Foundation

/// Secure storage implementation using the iOS Keychain.
///
/// Use this for sensitive data like tokens, passwords, and credentials.
/// Data is stored encrypted in the system keychain.
///
/// ## Topics
/// ### Initialization
/// - ``init(service:accessGroup:)``
///
/// ## Example
/// ```swift
/// struct AuthToken: Codable, Identifiable, Sendable {
///     let id: String
///     var token: String
///     var expiresAt: Date
/// }
///
/// let storage = KeychainStorage<AuthToken>(service: "com.myapp.auth")
/// try await storage.save(authToken)
/// ```
public actor KeychainStorage<T: Codable & Sendable & Identifiable>: StorageProvider where T.ID: LosslessStringConvertible {
    public typealias Entity = T

    private let service: String
    private let accessGroup: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a new keychain storage.
    ///
    /// - Parameters:
    ///   - service: The service identifier for keychain items
    ///   - accessGroup: Optional access group for shared keychain access
    public init(
        service: String,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
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

        if let accessGroup = accessGroup {
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
            throw StorageError.notFound(id: id)
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
        if status != errSecSuccess && status != errSecItemNotFound {
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
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
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
