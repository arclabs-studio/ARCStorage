import Foundation

/// A single page of results from a paginated fetch.
///
/// Encapsulates the items for the current page along with metadata to drive
/// infinite-scroll or page-based UIs without manually tracking offsets.
///
/// ## Example
/// ```swift
/// var page = 0
/// var loaded: [Restaurant] = []
/// while true {
///     let result = try repository.fetchPage(page, pageSize: 50)
///     loaded.append(contentsOf: result.items)
///     guard result.hasMore else { break }
///     page += 1
/// }
/// ```
public struct PagedResult<T> {
    /// The items in this page.
    public let items: [T]

    /// The zero-based index of this page.
    public let page: Int

    /// The maximum number of items per page requested by the caller.
    public let pageSize: Int

    /// The total number of items that match the query (ignoring limit/offset).
    public let totalCount: Int

    /// Creates a new paged result.
    ///
    /// - Parameters:
    ///   - items: The items in this page
    ///   - page: Zero-based page index
    ///   - pageSize: Page size requested by the caller
    ///   - totalCount: Total items matching the query
    public init(items: [T], page: Int, pageSize: Int, totalCount: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.totalCount = totalCount
    }

    /// `true` if there are more pages after this one.
    public var hasMore: Bool {
        (page + 1) * pageSize < totalCount
    }

    /// Total number of pages available for the query.
    public var pageCount: Int {
        guard pageSize > 0 else { return 0 }
        return (totalCount + pageSize - 1) / pageSize
    }
}

extension PagedResult: Sendable where T: Sendable {}
