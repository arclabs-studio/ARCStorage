import Foundation

/// Protocol for managing transactional operations.
///
/// Transaction contexts ensure that multiple operations either all succeed
/// or all fail together, maintaining data consistency.
///
/// ## Example
/// ```swift
/// try await storage.performTransaction {
///     try await storage.save(entity1)
///     try await storage.save(entity2)
///     try await storage.delete(id: oldEntityId)
/// }
/// ```
public protocol TransactionContext: Sendable {
    /// Begins a new transaction.
    func begin() async throws

    /// Commits the current transaction.
    func commit() async throws

    /// Rolls back the current transaction.
    func rollback() async throws
}
