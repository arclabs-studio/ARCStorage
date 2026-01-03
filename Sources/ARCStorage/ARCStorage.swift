import Foundation
import SwiftData

/// # ARCStorage
///
/// A protocol-based storage abstraction layer for iOS applications.
///
/// ARCStorage provides a clean, testable architecture for data persistence
/// supporting multiple backends including SwiftData, UserDefaults, Keychain,
/// and in-memory storage.
///
/// ## Overview
///
/// ARCStorage follows Clean Architecture principles with a repository pattern
/// that completely decouples your domain layer from persistence details.
///
/// ### Key Features
///
/// - **Protocol-First Design**: Abstract storage behind protocols
/// - **Multiple Backends**: SwiftData, UserDefaults, Keychain, in-memory
/// - **Thread-Safe**: Built with Swift 6 strict concurrency
/// - **Fully Testable**: Mocks and in-memory storage for tests
/// - **Caching**: Built-in LRU cache with configurable policies
/// - **Type-Safe**: Generic protocols with associated types
///
/// ## Topics
///
/// ### Core Protocols
/// - ``StorageProvider``
/// - ``Repository``
/// - ``CachePolicy``
/// - ``TransactionContext``
///
/// ### SwiftData Integration
/// - ``SwiftDataStorage``
/// - ``SwiftDataRepository``
/// - ``SwiftDataConfiguration``
///
/// ### Alternative Storage
/// - ``InMemoryStorage``
/// - ``InMemoryRepository``
/// - ``UserDefaultsStorage``
/// - ``UserDefaultsRepository``
/// - ``KeychainStorage``
/// - ``KeychainRepository``
///
/// ### Caching
/// - ``CacheManager``
/// - ``LRUCache``
/// - ``CacheStrategy``
///
/// ### Testing
/// - ``MockRepository``
/// - ``MockStorageProvider``
/// - ``TestHelpers``
///
/// ### CloudKit
/// - ``CloudKitConfiguration``
/// - ``CloudKitSyncMonitor``
///
/// ### Migration
/// - ``MigrationPlan``
/// - ``MigrationManager``
/// - ``MigrationHelper``
///
/// ### Error Handling
/// - ``StorageError``
///
/// ## Getting Started
///
/// ### 1. Define Your Model
///
/// For SwiftData, your model must conform to `PersistentModel`, `Identifiable`,
/// `Codable`, and `Sendable`:
///
/// ```swift
/// @Model
/// final class Restaurant: Identifiable, Codable {
///     @Attribute(.unique) var id: UUID
///     var name: String
///     var rating: Double
///
///     init(id: UUID = UUID(), name: String, rating: Double) {
///         self.id = id
///         self.name = name
///         self.rating = rating
///     }
/// }
/// ```
///
/// ### 2. Configure Storage
///
/// In your app initialization:
///
/// ```swift
/// import SwiftData
/// import ARCStorage
///
/// let config = SwiftDataConfiguration(
///     schema: Schema([Restaurant.self]),
///     isCloudKitEnabled: true
/// )
/// let container = try config.makeContainer()
/// ```
///
/// ### 3. Create Repository
///
/// ```swift
/// let storage = SwiftDataStorage<Restaurant>(modelContainer: container)
/// let repository = SwiftDataRepository(storage: storage)
/// ```
///
/// ### 4. Use in a View Model
///
/// ```swift
/// @MainActor
/// @Observable
/// final class RestaurantsStore {
///     private(set) var restaurants: [Restaurant] = []
///     private let repository: any Repository<Restaurant>
///
///     init(repository: any Repository<Restaurant>) {
///         self.repository = repository
///     }
///
///     func loadRestaurants() async {
///         do {
///             restaurants = try await repository.fetchAll()
///         } catch {
///             print("Error: \(error)")
///         }
///     }
/// }
/// ```
///
/// ## Testing
///
/// ARCStorage provides comprehensive testing utilities:
///
/// ```swift
/// func testViewModel() async throws {
///     let mockRepo = MockRepository<Restaurant>()
///     mockRepo.mockEntities = [.fixture1, .fixture2]
///
///     let viewModel = RestaurantsViewModel(repository: mockRepo)
///     await viewModel.loadRestaurants()
///
///     XCTAssertEqual(viewModel.restaurants.count, 2)
/// }
/// ```
///
/// ## Best Practices
///
/// 1. **Use Repositories in Domain Layer**: Never use `@Query` in ViewModels
/// 2. **Inject Dependencies**: Pass repositories through initializers
/// 3. **Cache Wisely**: Choose appropriate cache policies for your data
/// 4. **Test with Mocks**: Use `MockRepository` for unit tests
/// 5. **Use InMemory for Integration**: Fast, isolated integration tests
///
/// ## See Also
///
/// - <doc:GettingStarted>
/// - <doc:SwiftDataIntegration>
/// - <doc:RepositoryPattern>
/// - <doc:Testing>
public enum ARCStorage {
    /// Current version of ARCStorage.
    public static let version = "1.0.0"

    /// Framework identifier.
    public static let identifier = "com.arclabs.arcstorage"
}
