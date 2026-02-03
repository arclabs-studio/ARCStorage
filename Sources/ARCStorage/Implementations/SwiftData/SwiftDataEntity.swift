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
/// ## Best Practices
///
/// ### Use @Attribute(.unique) for ID Properties
///
/// Adding `@Attribute(.unique)` to your `id` property creates a database index, enabling
/// O(1) lookups by ID instead of O(n) table scans:
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)  // Creates database index for fast lookups
///     var id: UUID = UUID()
///     var name: String = ""
///     var rating: Double = 0.0
/// }
/// ```
///
/// ### CloudKit Compatibility
///
/// When using CloudKit synchronization, your models must follow specific requirements:
///
/// - **All properties must be optional OR have default values**
/// - **All relationships must be optional**
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()          // ✅ Has default value
///     var name: String = ""          // ✅ Has default value
///     var description: String?       // ✅ Optional
///     var rating: Double?            // ✅ Optional
///
///     @Relationship(deleteRule: .cascade)
///     var reviews: [Review]?         // ✅ Optional relationship
///
///     var owner: Owner?              // ✅ Optional inverse relationship
/// }
/// ```
///
/// ### Property Transformations
///
/// For complex types that aren't natively supported by SwiftData, use transformable attributes:
///
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()
///
///     @Attribute(.transformable(by: CLLocationCoordinate2DTransformer.self))
///     var location: CLLocationCoordinate2D?
/// }
/// ```
///
/// ## Example
///
/// ### Basic Model
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()
///     var name: String = ""
///     var cuisine: String = ""
///     var rating: Double = 0.0
///
///     init(id: UUID = UUID(), name: String, cuisine: String, rating: Double = 0.0) {
///         self.id = id
///         self.name = name
///         self.cuisine = cuisine
///         self.rating = rating
///     }
/// }
/// ```
///
/// ### Model with Relationships
/// ```swift
/// @Model
/// final class Restaurant: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()
///     var name: String = ""
///
///     @Relationship(deleteRule: .cascade, inverse: \Review.restaurant)
///     var reviews: [Review]? = []
/// }
///
/// @Model
/// final class Review: SwiftDataEntity {
///     @Attribute(.unique)
///     var id: UUID = UUID()
///     var text: String = ""
///     var rating: Int = 0
///
///     var restaurant: Restaurant?
/// }
/// ```
///
/// ## Note
///
/// For storage backends that require `Sendable` (UserDefaults, Keychain, InMemory),
/// use structs that conform to ``StorageProvider``'s entity requirements.
public protocol SwiftDataEntity: PersistentModel, Identifiable where ID: Hashable {}
