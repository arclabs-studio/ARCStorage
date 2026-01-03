import Foundation
import SwiftData

// Note: ModelContextProvider has been removed as ModelContext is not Sendable
// and cannot be safely shared across actor boundaries in Swift 6.
//
// Use @ModelActor actors directly for SwiftData operations.
// See SwiftDataStorage for the recommended pattern.
