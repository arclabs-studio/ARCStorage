import Foundation

/// Thread-safe cache manager for repository layer.
///
/// `CacheManager` provides an LRU (Least Recently Used) cache implementation
/// with configurable TTL and capacity limits.
///
/// ## Topics
/// ### Cache Operations
/// - ``get(_:)``
/// - ``set(_:for:)``
/// - ``invalidate()``
/// - ``invalidate(_:)``
///
/// ## Example
/// ```swift
/// let cache = CacheManager<UUID, Restaurant>(policy: .default)
/// await cache.set(restaurant, for: restaurant.id)
/// let cached = await cache.get(restaurant.id)
/// ```
public actor CacheManager<Key: Hashable & Sendable, Value: Sendable> {
    private var cache: [Key: CacheEntry<Value>] = [:]
    private var accessOrder: [Key] = []
    private let policy: CachePolicy

    /// Creates a new cache manager.
    ///
    /// - Parameter policy: The caching policy to use
    public init(policy: CachePolicy) {
        self.policy = policy
    }

    /// Retrieves a value from the cache.
    ///
    /// Returns `nil` if the key is not found or the entry has expired.
    /// Updates the access order for LRU eviction.
    ///
    /// - Parameter key: The key to look up
    /// - Returns: The cached value if found and not expired, `nil` otherwise
    public func get(_ key: Key) -> Value? {
        guard let entry = cache[key] else {
            return nil
        }

        // Check if entry has expired
        if policy.ttl > 0 {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age > policy.ttl {
                cache.removeValue(forKey: key)
                accessOrder.removeAll { $0 == key }
                return nil
            }
        }

        // Update access order for LRU
        updateAccessOrder(for: key)

        return entry.value
    }

    /// Stores a value in the cache.
    ///
    /// If the cache is full, evicts entries according to the cache policy.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The key to associate with the value
    public func set(_ value: Value, for key: Key) {
        // Don't cache if policy doesn't allow it
        guard policy.maxSize > 0 else { return }

        // Evict if needed
        if cache.count >= policy.maxSize, cache[key] == nil {
            evictEntries(count: 1)
        }

        let entry = CacheEntry(value: value, timestamp: Date())
        cache[key] = entry
        updateAccessOrder(for: key)
    }

    /// Removes a specific entry from the cache.
    ///
    /// - Parameter key: The key to invalidate
    public func invalidate(_ key: Key) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    /// Clears all entries from the cache.
    public func invalidate() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Returns the current number of cached entries.
    public var count: Int {
        cache.count
    }

    // MARK: - Private Methods

    private func updateAccessOrder(for key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictEntries(count: Int) {
        let keysToEvict: [Key]

        switch policy.strategy {
        case .lru:
            keysToEvict = Array(accessOrder.prefix(count))
        case .fifo:
            keysToEvict = Array(cache.keys.prefix(count))
        }

        for key in keysToEvict {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }
}

/// Internal cache entry storing value and metadata.
struct CacheEntry<Value: Sendable>: Sendable {
    let value: Value
    let timestamp: Date
}
