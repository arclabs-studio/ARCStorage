import Foundation

/// Storage implementation using UserDefaults.
///
/// Suitable for simple key-value data like preferences and settings.
/// Data is persisted using JSON encoding.
///
/// ## Topics
/// ### Initialization
/// - ``init(userDefaults:keyPrefix:)``
///
/// ## Example
/// ```swift
/// struct Settings: Codable, Identifiable, Sendable {
///     let id: String
///     var darkMode: Bool
///     var notifications: Bool
/// }
///
/// let storage = UserDefaultsStorage<Settings>()
/// try await storage.save(settings)
/// ```
public actor UserDefaultsStorage<T: Codable & Sendable & Identifiable>: StorageProvider
where T.ID: LosslessStringConvertible & Sendable & Hashable {
    public typealias Entity = T

    private let userDefaults: UserDefaults
    private let keyPrefix: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a new UserDefaults storage.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use
    ///   - keyPrefix: Prefix for all keys to avoid conflicts
    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "ARCStorage"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    public func save(_ entity: T) async throws {
        let key = makeKey(for: entity.id)

        do {
            let data = try encoder.encode(entity)
            userDefaults.set(data, forKey: key)
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
        let key = makeKey(for: id)

        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    public func fetchAll() async throws -> [T] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefixedKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        var entities: [T] = []

        for key in prefixedKeys {
            guard let data = userDefaults.data(forKey: key) else { continue }

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
        let key = makeKey(for: id)

        guard userDefaults.object(forKey: key) != nil else {
            throw StorageError.entityNotFound(id: id)
        }

        userDefaults.removeObject(forKey: key)
    }

    public func deleteAll() async throws {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefixedKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        for key in prefixedKeys {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func performTransaction<Result: Sendable>(
        _ block: @Sendable () async throws -> Result
    ) async throws -> Result {
        // UserDefaults doesn't support transactions, so we just execute the block
        do {
            return try await block()
        } catch {
            throw StorageError.transactionFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func makeKey(for id: T.ID) -> String {
        "\(keyPrefix).\(String(id))"
    }
}
