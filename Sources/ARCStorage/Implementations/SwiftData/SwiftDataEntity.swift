import Foundation
import SwiftData

/// Protocol for SwiftData entities that can be used with ``SwiftDataStorage`` and ``SwiftDataRepository``.
///
/// This protocol has relaxed constraints compared to ``StorageProvider`` and ``Repository`` because
/// SwiftData `@Model` classes cannot conform to `Sendable` in Swift 6 strict concurrency mode.
///
/// ## Why Not Sendable?
///
/// In Swift 6, the `@Model` macro generates conformances that are isolated to the main actor.
/// This makes it impossible for `@Model` classes to safely conform to `Sendable`.
///
/// ## Why Not Codable?
///
/// While `@Model` classes can technically conform to `Codable`, the generated conformances
/// may conflict with the macro-generated code in Swift 6. SwiftData handles serialization
/// internally, so `Codable` conformance is not required for persistence.
///
/// ## Example
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     var id: UUID
///     var name: String
///
///     init(id: UUID = UUID(), name: String) {
///         self.id = id
///         self.name = name
///     }
/// }
/// ```
///
/// ## Note
///
/// For storage backends that require `Sendable` (UserDefaults, Keychain, InMemory),
/// use structs that conform to ``StorageProvider``'s entity requirements.
public protocol SwiftDataEntity: PersistentModel, Identifiable where ID: Hashable {}
