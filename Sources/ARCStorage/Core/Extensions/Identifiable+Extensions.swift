import Foundation

extension Identifiable where Self: Sendable {
    /// Returns whether this entity has the same ID as another.
    ///
    /// - Parameter other: Another identifiable entity
    /// - Returns: `true` if IDs match, `false` otherwise
    public func isSameEntity(as other: Self) -> Bool where ID: Equatable {
        id == other.id
    }
}

extension Array where Element: Identifiable & Sendable {
    /// Finds an entity by its identifier.
    ///
    /// - Parameter id: The identifier to search for
    /// - Returns: The entity if found, `nil` otherwise
    public func find(by id: Element.ID) -> Element? where Element.ID: Equatable {
        first { $0.id == id }
    }

    /// Removes duplicate entities based on their identifiers.
    ///
    /// When duplicates are found, the first occurrence is kept.
    ///
    /// - Returns: Array with unique entities
    public func uniqueByID() -> [Element] where Element.ID: Hashable {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}
