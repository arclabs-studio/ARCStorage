import Foundation

/// Result of a `fetchAll` operation that includes diagnostic information.
///
/// Use ``FetchResult`` when you need visibility into data integrity issues.
/// Unlike `fetchAll()`, which silently skips corrupted entries,
/// `fetchAllWithDiagnostics()` returns both the valid entities and a count
/// of entries that failed to decode.
///
/// ## Example
/// ```swift
/// let result = await storage.fetchAllWithDiagnostics()
/// if result.hasCorruption {
///     logger.warning("Found \(result.corruptedCount) corrupted entries")
/// }
/// let entities = result.entities
/// ```
public struct FetchResult<T: Sendable>: Sendable {
    /// The successfully decoded entities.
    public let entities: [T]

    /// Number of entries that failed to decode and were skipped.
    public let corruptedCount: Int

    /// Whether any entries were skipped due to corruption.
    public var hasCorruption: Bool {
        corruptedCount > 0
    }

    /// Creates a new fetch result.
    ///
    /// - Parameters:
    ///   - entities: Successfully decoded entities
    ///   - corruptedCount: Number of corrupted entries skipped
    public init(entities: [T], corruptedCount: Int) {
        self.entities = entities
        self.corruptedCount = corruptedCount
    }
}
