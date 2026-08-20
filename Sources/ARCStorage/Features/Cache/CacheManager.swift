import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Eviction Events

/// Describes a cache eviction that occurred.
///
/// Subscribe to ``CacheManager/evictionEvents`` to observe when entries
/// are removed from the cache, e.g. to update UI or trigger re-fetches.
public struct CacheEvictionEvent<Key: Hashable & Sendable>: Sendable {
    /// The keys that were evicted.
    public let evictedKeys: [Key]

    /// Why the eviction occurred.
    public let reason: EvictionReason

    /// Number of entries remaining in the cache after eviction.
    public let remainingCount: Int
}

/// Why a cache eviction occurred.
public enum EvictionReason: Sendable {
    /// Cache item count exceeded ``CachePolicy/maxSize``.
    case capacityLimit

    /// Cache byte size exceeded ``CachePolicy/maxByteSize``.
    case byteSizeLimit

    /// System reported memory pressure.
    case memoryPressure(MemoryPressureLevel)

    /// Caller explicitly invalidated entries.
    case manual
}

// MARK: - CacheManager

/// Thread-safe cache manager for repository layer.
///
/// `CacheManager` provides an LRU (Least Recently Used) cache implementation
/// with configurable TTL, count, and byte-size limits. It automatically
/// responds to system memory pressure by evicting entries and publishes
/// eviction events via ``evictionEvents``.
///
/// ## Topics
/// ### Cache Operations
/// - ``get(_:)``
/// - ``set(_:for:)``
/// - ``invalidate()``
/// - ``invalidate(_:)``
///
/// ### Memory Management
/// - ``handleMemoryPressure(level:)``
/// - ``MemoryPressureLevel``
///
/// ### Eviction Observation
/// - ``evictionEvents``
/// - ``CacheEvictionEvent``
/// - ``EvictionReason``
///
/// ### Diagnostics
/// - ``count``
/// - ``currentByteSizeUsed``
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
    private var currentByteSize: Int = 0

    /// Stream of eviction events. Subscribe to observe when entries are removed.
    public nonisolated let evictionEvents: AsyncStream<CacheEvictionEvent<Key>>
    private let evictionContinuation: AsyncStream<CacheEvictionEvent<Key>>.Continuation

    /// The memory pressure handler for this cache.
    private var memoryPressureHandler: MemoryPressureHandler?

    /// Creates a new cache manager.
    ///
    /// - Parameters:
    ///   - policy: The caching policy to use
    ///   - registerForMemoryWarnings: Whether to automatically clear cache on memory warnings.
    ///     Defaults to `true`.
    public init(policy: CachePolicy, registerForMemoryWarnings: Bool = true) {
        self.policy = policy

        let (stream, continuation) = AsyncStream<CacheEvictionEvent<Key>>.makeStream()
        evictionEvents = stream
        evictionContinuation = continuation

        if registerForMemoryWarnings {
            Task { [weak self] in
                await self?.setupMemoryPressureHandling()
            }
        }
    }

    deinit {
        evictionContinuation.finish()
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
                currentByteSize -= entry.byteSize
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
    /// If the cache is full (by count or byte size), evicts entries according
    /// to the cache policy.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The key to associate with the value
    public func set(_ value: Value, for key: Key) {
        // Don't cache if policy doesn't allow it
        guard policy.maxSize > 0 else { return }

        let entryByteSize = (value as? ByteSizable)?.byteSize ?? 0

        // Remove existing entry's byte size if updating
        if let existing = cache[key] {
            currentByteSize -= existing.byteSize
        }

        // Evict by count if needed
        if cache.count >= policy.maxSize, cache[key] == nil {
            evictEntries(count: 1, reason: .capacityLimit)
        }

        // Evict by byte size if needed
        if let maxBytes = policy.maxByteSize, maxBytes > 0 {
            var evictedKeys: [Key] = []
            while currentByteSize + entryByteSize > maxBytes, !accessOrder.isEmpty {
                let lruKey = accessOrder[0]
                if let evicted = cache[lruKey] {
                    currentByteSize -= evicted.byteSize
                }
                cache.removeValue(forKey: lruKey)
                accessOrder.removeFirst()
                evictedKeys.append(lruKey)
            }
            if !evictedKeys.isEmpty {
                let event = CacheEvictionEvent(evictedKeys: evictedKeys,
                                               reason: .byteSizeLimit,
                                               remainingCount: cache.count)
                evictionContinuation.yield(event)
            }
        }

        let entry = CacheEntry(value: value, timestamp: Date(), byteSize: entryByteSize)
        cache[key] = entry
        currentByteSize += entryByteSize
        updateAccessOrder(for: key)
    }

    /// Removes a specific entry from the cache.
    ///
    /// - Parameter key: The key to invalidate
    public func invalidate(_ key: Key) {
        if let entry = cache[key] {
            currentByteSize -= entry.byteSize
        }
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    /// Clears all entries from the cache.
    public func invalidate() {
        let keys = Array(cache.keys)
        cache.removeAll()
        accessOrder.removeAll()
        currentByteSize = 0

        if !keys.isEmpty {
            let event = CacheEvictionEvent(evictedKeys: keys,
                                           reason: .manual,
                                           remainingCount: 0)
            evictionContinuation.yield(event)
        }
    }

    /// Returns the current number of cached entries.
    public var count: Int {
        cache.count
    }

    /// Returns the current total byte size of cached entries.
    ///
    /// Only meaningful when cached values conform to ``ByteSizable``.
    /// Returns 0 for non-`ByteSizable` values.
    public var currentByteSizeUsed: Int {
        currentByteSize
    }

    // MARK: - Memory Pressure Handling

    /// Handles memory pressure by evicting cache entries.
    ///
    /// - Parameter level: The severity of memory pressure
    public func handleMemoryPressure(level: MemoryPressureLevel) {
        switch level {
        case .warning:
            // Evict 50% of entries on warning
            let toEvict = max(1, cache.count / 2)
            evictEntries(count: toEvict, reason: .memoryPressure(.warning))

        case .critical:
            // Clear everything on critical pressure
            let keys = Array(cache.keys)
            cache.removeAll()
            accessOrder.removeAll()
            currentByteSize = 0

            if !keys.isEmpty {
                let event = CacheEvictionEvent(evictedKeys: keys,
                                               reason: .memoryPressure(.critical),
                                               remainingCount: 0)
                evictionContinuation.yield(event)
            }
        }
    }

    // MARK: - Private Methods

    private func setupMemoryPressureHandling() {
        memoryPressureHandler = MemoryPressureHandler { [weak self] level in
            guard let self else { return }
            Task {
                await self.handleMemoryPressure(level: level)
            }
        }
    }

    private func updateAccessOrder(for key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictEntries(count: Int, reason: EvictionReason) {
        let keysToEvict: [Key] = switch policy.strategy {
        case .lru:
            Array(accessOrder.prefix(count))
        case .fifo:
            Array(cache.keys.prefix(count))
        }

        for key in keysToEvict {
            if let entry = cache[key] {
                currentByteSize -= entry.byteSize
            }
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }

        if !keysToEvict.isEmpty {
            let event = CacheEvictionEvent(evictedKeys: keysToEvict,
                                           reason: reason,
                                           remainingCount: cache.count)
            evictionContinuation.yield(event)
        }
    }
}

// MARK: - Memory Pressure Level

/// Represents the severity of memory pressure from the system.
public enum MemoryPressureLevel: Sendable {
    /// Moderate memory pressure - should reduce memory usage.
    case warning

    /// Critical memory pressure - should release as much memory as possible.
    case critical
}

// MARK: - Memory Pressure Handler

/// Handles system memory pressure notifications.
final class MemoryPressureHandler: @unchecked Sendable {
    private let callback: @Sendable (MemoryPressureLevel) -> Void

    #if os(macOS)
    private var dispatchSource: DispatchSourceMemoryPressure?
    #endif

    init(callback: @escaping @Sendable (MemoryPressureLevel) -> Void) {
        self.callback = callback
        setupNotifications()
    }

    deinit {
        teardownNotifications()
    }

    private func setupNotifications() {
        #if canImport(UIKit) && !os(watchOS)
        // iOS, tvOS, visionOS
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryWarning),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
        #elseif os(macOS)
        // macOS uses dispatch source for memory pressure
        dispatchSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                                 queue: .main)
        dispatchSource?.setEventHandler { [weak self] in
            guard let source = self?.dispatchSource else { return }
            let event = source.data
            if event.contains(.critical) {
                self?.callback(.critical)
            } else if event.contains(.warning) {
                self?.callback(.warning)
            }
        }
        dispatchSource?.resume()
        #elseif os(watchOS)
        // watchOS - use ProcessInfo for memory warnings
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryWarning),
                                               name: .init("NSProcessInfoPowerStateDidChangeNotification"),
                                               object: nil)
        #endif
    }

    private func teardownNotifications() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didReceiveMemoryWarningNotification,
                                                  object: nil)
        #elseif os(macOS)
        dispatchSource?.cancel()
        dispatchSource = nil
        #elseif os(watchOS)
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    @objc private func handleMemoryWarning() {
        callback(.warning)
    }
}

// MARK: - Cache Entry

/// Internal cache entry storing value and metadata.
struct CacheEntry<Value: Sendable> {
    let value: Value
    let timestamp: Date
    let byteSize: Int
}
