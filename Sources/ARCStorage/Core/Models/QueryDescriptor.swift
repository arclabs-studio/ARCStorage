import Foundation

/// Describes a query operation for fetching entities.
///
/// Query descriptors encapsulate filtering, sorting, and pagination
/// parameters for data retrieval.
///
/// ## Example
/// ```swift
/// let query = QueryDescriptor<Restaurant>(
///     predicate: #Predicate { $0.rating >= 4.0 },
///     sortBy: [SortDescriptor(\.name, order: .ascending)],
///     limit: 20
/// )
/// ```
public struct QueryDescriptor<T: Sendable>: Sendable {
    /// Optional predicate to filter results.
    public let predicate: Predicate<T>?

    /// Sort descriptors for ordering results.
    public let sortBy: [SortDescriptor<T>]

    /// Maximum number of results to return.
    public let limit: Int?

    /// Number of results to skip.
    public let offset: Int?

    /// Creates a new query descriptor.
    ///
    /// - Parameters:
    ///   - predicate: Optional filter predicate
    ///   - sortBy: Sort descriptors
    ///   - limit: Maximum results
    ///   - offset: Results to skip
    public init(
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.predicate = predicate
        self.sortBy = sortBy
        self.limit = limit
        self.offset = offset
    }
}
