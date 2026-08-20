import Foundation

/// A type that can report its approximate byte size in memory.
///
/// Conform to this protocol to enable byte-size-based cache eviction
/// in ``CacheManager`` and ``LRUCache``. When cached values conform to
/// `ByteSizable`, the cache can enforce ``CachePolicy/maxByteSize`` limits.
///
/// ## Example
/// ```swift
/// struct CachedImage: ByteSizable, Sendable {
///     let data: Data
///     var byteSize: Int { data.count }
/// }
///
/// let policy = CachePolicy.photo(maxMB: 50)
/// let cache = CacheManager<UUID, CachedImage>(policy: policy)
/// ```
public protocol ByteSizable {
    /// The approximate size of this value in bytes.
    var byteSize: Int { get }
}

extension Data: ByteSizable {
    public var byteSize: Int {
        count
    }
}
