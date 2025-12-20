import Foundation

/// Defines caching behavior for repositories.
///
/// Cache policies control how long data is kept in memory and which
/// eviction strategy is used when the cache is full.
///
/// ## Topics
/// ### Predefined Policies
/// - ``default``
/// - ``aggressive``
/// - ``noCache``
///
/// ## Example
/// ```swift
/// let policy = CachePolicy(
///     ttl: 300,  // 5 minutes
///     maxSize: 100,
///     strategy: .lru
/// )
/// ```
public struct CachePolicy: Sendable {
    /// Time-to-live for cached items in seconds.
    public let ttl: TimeInterval

    /// Maximum number of items to keep in cache.
    public let maxSize: Int

    /// Strategy for evicting items when cache is full.
    public let strategy: CacheStrategy

    /// Creates a new cache policy.
    ///
    /// - Parameters:
    ///   - ttl: Time-to-live in seconds
    ///   - maxSize: Maximum cache size
    ///   - strategy: Eviction strategy
    public init(ttl: TimeInterval, maxSize: Int, strategy: CacheStrategy) {
        self.ttl = ttl
        self.maxSize = maxSize
        self.strategy = strategy
    }

    /// Default cache policy with 5-minute TTL and 100-item capacity.
    public static let `default` = CachePolicy(
        ttl: 300,
        maxSize: 100,
        strategy: .lru
    )

    /// Aggressive cache policy with 1-hour TTL and 500-item capacity.
    ///
    /// Use this for data that changes infrequently.
    public static let aggressive = CachePolicy(
        ttl: 3600,
        maxSize: 500,
        strategy: .lru
    )

    /// Disables caching completely.
    ///
    /// Use this when data must always be fresh from storage.
    public static let noCache = CachePolicy(
        ttl: 0,
        maxSize: 0,
        strategy: .lru
    )
}

/// Strategy for evicting cache entries when capacity is reached.
public enum CacheStrategy: Sendable {
    /// Least Recently Used - evicts items that haven't been accessed recently.
    case lru

    /// First In First Out - evicts oldest items first.
    case fifo
}
