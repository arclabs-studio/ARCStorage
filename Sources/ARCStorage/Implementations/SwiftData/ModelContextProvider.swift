import SwiftData
import Foundation

/// Protocol for types that provide access to a ModelContext.
///
/// This protocol enables dependency injection of ModelContext
/// for testing and flexibility.
public protocol ModelContextProvider: Sendable {
    /// The model context for SwiftData operations.
    var modelContext: ModelContext { get }
}

/// Default implementation using ModelContainer.
@ModelActor
public actor DefaultModelContextProvider: ModelContextProvider {
    /// Creates a provider with the specified container.
    ///
    /// - Parameter modelContainer: The container to use
    public init(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialExecutor()
        self.modelContainer = modelContainer
    }
}
