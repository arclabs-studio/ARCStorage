import Foundation

extension Predicate where Output: Identifiable & Sendable {
    /// Creates a predicate that matches an entity by ID.
    ///
    /// - Parameter id: The identifier to match
    /// - Returns: A predicate matching the specified ID
    public static func matchingID(_ id: Output.ID) -> Predicate<Output> where Output.ID: Equatable {
        #Predicate<Output> { entity in
            entity.id == id
        }
    }
}

extension Array where Element: Sendable {
    /// Filters array elements using a Foundation Predicate.
    ///
    /// - Parameter predicate: The predicate to apply
    /// - Returns: Filtered array
    public func filter(using predicate: Predicate<Element>) throws -> [Element] {
        try self.filter { element in
            try predicate.evaluate(element)
        }
    }
}
