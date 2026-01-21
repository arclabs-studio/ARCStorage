import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thread-safe cache manager for repository layer.
///
/// `CacheManager` provides an LRU (Least Recently Used) cache implementation
/// with configurable TTL and capacity limits. It automatically responds to
/// system memory pressure by evicting entries.
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

        if registerForMemoryWarnings {
            Task { [weak self] in
                await self?.setupMemoryPressureHandling()
            }
        }
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

    // MARK: - Memory Pressure Handling

    /// Handles memory pressure by evicting cache entries.
    ///
    /// - Parameter level: The severity of memory pressure
    public func handleMemoryPressure(level: MemoryPressureLevel) {
        switch level {
        case .warning:
            // Evict 50% of entries on warning
            let toEvict = max(1, cache.count / 2)
            evictEntries(count: toEvict)

        case .critical:
            // Clear everything on critical pressure
            invalidate()
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

    private func evictEntries(count: Int) {
        // swiftlint:disable switch_case_alignment
        let keysToEvict: [Key] = switch policy.strategy {
        case .lru:
            Array(accessOrder.prefix(count))
        case .fifo:
            Array(cache.keys.prefix(count))
        }
        // swiftlint:enable switch_case_alignment

        for key in keysToEvict {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #elseif os(macOS)
        // macOS uses dispatch source for memory pressure
        dispatchSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: .init("NSProcessInfoPowerStateDidChangeNotification"),
            object: nil
        )
        #endif
    }

    private func teardownNotifications() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #elseif os(macOS)
        dispatchSource?.cancel()
        dispatchSource = nil
        #elseif os(watchOS)
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    @objc
    private func handleMemoryWarning() {
        callback(.warning)
    }
}

// MARK: - Cache Entry

/// Internal cache entry storing value and metadata.
struct CacheEntry<Value: Sendable>: Sendable {
    let value: Value
    let timestamp: Date
}
