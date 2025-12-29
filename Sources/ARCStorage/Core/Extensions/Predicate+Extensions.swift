import Foundation

// Note: Predicate extensions with generics have been removed due to
// limitations in Swift's #Predicate macro with generic types.
//
// Use concrete predicates directly:
// ```swift
// let predicate = #Predicate<Restaurant> { $0.id == targetID }
// ```

extension Array where Element: Sendable {
    /// Filters array elements using a Foundation Predicate.
    ///
    /// - Parameter predicate: The predicate to apply
    /// - Returns: Filtered array
    public func filter(using predicate: Predicate<Element>) throws -> [Element] {
        try filter { element in
            try predicate.evaluate(element)
        }
    }
}
