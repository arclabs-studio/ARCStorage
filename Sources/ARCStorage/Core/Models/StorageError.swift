import Foundation

/// Errors that can occur during storage operations.
///
/// All storage providers throw `StorageError` for consistent error handling
/// across different storage backends.
///
/// ## Topics
/// ### Error Cases
/// - ``notFound(id:)``
/// - ``saveFailed(underlying:)``
/// - ``fetchFailed(underlying:)``
/// - ``deleteFailed(underlying:)``
/// - ``invalidData``
/// - ``transactionFailed(underlying:)``
public enum StorageError: Error, @unchecked Sendable {
    /// Entity with the specified ID was not found.
    case notFound(id: String)

    /// Save operation failed.
    case saveFailed(underlying: Error)

    /// Fetch operation failed.
    case fetchFailed(underlying: Error)

    /// Delete operation failed.
    case deleteFailed(underlying: Error)

    /// Data is invalid or corrupted.
    case invalidData

    /// Transaction failed and was rolled back.
    case transactionFailed(underlying: Error)

    /// Creates a notFound error from any ID type.
    ///
    /// - Parameter id: The ID that was not found
    /// - Returns: A StorageError.notFound with string representation of the ID
    public static func entityNotFound<ID>(id: ID) -> StorageError {
        .notFound(id: String(describing: id))
    }
}

extension StorageError: LocalizedError {
    /// User-friendly error descriptions.
    public var errorDescription: String? {
        switch self {
        case let .notFound(id):
            return "Entity with ID '\(id)' was not found"
        case let .saveFailed(error):
            return "Failed to save entity: \(error.localizedDescription)"
        case let .fetchFailed(error):
            return "Failed to fetch entities: \(error.localizedDescription)"
        case let .deleteFailed(error):
            return "Failed to delete entity: \(error.localizedDescription)"
        case .invalidData:
            return "Data is invalid or corrupted"
        case let .transactionFailed(error):
            return "Transaction failed: \(error.localizedDescription)"
        }
    }
}

extension StorageError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown storage error"
    }
}
