import Foundation
import SwiftData

/// A SwiftData-specific query bundle.
///
/// Mirrors ``QueryDescriptor`` but is **not** `Sendable` and uses
/// `Foundation.SortDescriptor` directly. This separation exists because
/// SwiftData `@Model` classes cannot conform to `Sendable` in Swift 6
/// strict concurrency mode, which makes the generic ``QueryDescriptor``
/// (constrained to `T: Sendable`) incompatible with ``SwiftDataEntity``.
///
/// All ``SwiftDataStorage`` and ``SwiftDataRepository`` instances run on
/// the main actor, so the lack of `Sendable` conformance is safe.
///
/// ## Example
/// ```swift
/// let query = SwiftDataQuery<Restaurant>(
///     predicate: #Predicate { $0.rating >= 4.0 },
///     sortBy: [Foundation.SortDescriptor(\.name)],
///     limit: 20,
///     offset: 0,
///     prefetching: [\.reviews]
/// )
/// let restaurants = try storage.fetch(query)
/// ```
public struct SwiftDataQuery<T: SwiftDataEntity> {
    /// Optional predicate to filter results.
    public let predicate: Predicate<T>?

    /// Sort descriptors for ordering results.
    public let sortBy: [Foundation.SortDescriptor<T>]

    /// Maximum number of results to return.
    public let limit: Int?

    /// Number of results to skip.
    public let offset: Int?

    /// Key paths to relationships that should be prefetched (avoids N+1 faults).
    public let prefetching: [PartialKeyPath<T>]

    /// Creates a new SwiftData query.
    ///
    /// - Parameters:
    ///   - predicate: Optional filter predicate
    ///   - sortBy: Sort descriptors
    ///   - limit: Maximum results (maps to `FetchDescriptor.fetchLimit`)
    ///   - offset: Results to skip (maps to `FetchDescriptor.fetchOffset`)
    ///   - prefetching: Relationship key paths to prefetch
    public init(
        predicate: Predicate<T>? = nil,
        sortBy: [Foundation.SortDescriptor<T>] = [],
        limit: Int? = nil,
        offset: Int? = nil,
        prefetching: [PartialKeyPath<T>] = []
    ) {
        self.predicate = predicate
        self.sortBy = sortBy
        self.limit = limit
        self.offset = offset
        self.prefetching = prefetching
    }
}
