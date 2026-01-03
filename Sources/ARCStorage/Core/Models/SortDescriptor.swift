import Foundation

/// Describes how to sort query results.
///
/// Sort descriptors specify a key path and sort order for organizing
/// fetched entities.
///
/// ## Example
/// ```swift
/// let nameSort = SortDescriptor(\.name, order: .ascending)
/// let dateSort = SortDescriptor(\.createdAt, order: .descending)
/// ```
public struct SortDescriptor<T: Sendable>: @unchecked Sendable {
    /// The key path to sort by.
    public let keyPath: PartialKeyPath<T>

    /// The sort order.
    public let order: SortOrder

    /// Creates a new sort descriptor.
    ///
    /// - Parameters:
    ///   - keyPath: Property to sort by
    ///   - order: Sort direction
    public init(_ keyPath: PartialKeyPath<T>, order: SortOrder) {
        self.keyPath = keyPath
        self.order = order
    }
}

/// Sort order for query results.
public enum SortOrder: Sendable {
    /// Ascending order (A-Z, 0-9, oldest-newest).
    case ascending

    /// Descending order (Z-A, 9-0, newest-oldest).
    case descending
}
