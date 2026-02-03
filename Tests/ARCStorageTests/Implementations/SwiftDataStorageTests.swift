import Foundation
import SwiftData
import Testing
@testable import ARCStorage

/// Test model that conforms to SwiftDataEntity.
/// This model does NOT conform to Sendable or Codable, demonstrating
/// Swift 6 strict concurrency compatibility.
@Model
final class TestSwiftDataModel: SwiftDataEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var value: Int

    init(id: UUID = UUID(), name: String, value: Int) {
        self.id = id
        self.name = name
        self.value = value
    }
}

@Suite("SwiftData Storage Tests")
@MainActor
struct SwiftDataStorageTests {
    /// Creates a new in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Save and fetch entity")
    func saveAndFetch() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model = TestSwiftDataModel(name: "Test", value: 42)
        let modelID = model.id

        try storage.save(model)

        let fetched = try storage.fetch(id: modelID)
        #expect(fetched != nil)
        #expect(fetched?.name == "Test")
        #expect(fetched?.value == 42)
    }

    @Test("Fetch all entities")
    func fetchAll() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model1 = TestSwiftDataModel(name: "First", value: 1)
        let model2 = TestSwiftDataModel(name: "Second", value: 2)

        try storage.save(model1)
        try storage.save(model2)

        let all = try storage.fetchAll()
        #expect(all.count == 2)
    }

    @Test("Delete entity")
    func deleteEntity() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model = TestSwiftDataModel(name: "ToDelete", value: 99)
        let modelID = model.id

        try storage.save(model)
        try storage.delete(id: modelID)

        let fetched = try storage.fetch(id: modelID)
        #expect(fetched == nil)
    }

    @Test("Delete non-existent entity throws error")
    func deleteNonExistent() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        #expect(throws: StorageError.self) {
            try storage.delete(id: UUID())
        }
    }

    @Test("Save all entities in batch")
    func saveAllBatch() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "Batch1", value: 10),
            TestSwiftDataModel(name: "Batch2", value: 20),
            TestSwiftDataModel(name: "Batch3", value: 30)
        ]

        try storage.saveAll(models)

        let all = try storage.fetchAll()
        #expect(all.count == 3)
    }

    @Test("Delete all entities")
    func deleteAll() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "A", value: 1),
            TestSwiftDataModel(name: "B", value: 2)
        ]

        try storage.saveAll(models)
        try storage.deleteAll()

        let all = try storage.fetchAll()
        #expect(all.isEmpty)
    }

    @Test("Fetch with predicate")
    func fetchWithPredicate() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "Low", value: 10),
            TestSwiftDataModel(name: "High", value: 100),
            TestSwiftDataModel(name: "Medium", value: 50)
        ]

        try storage.saveAll(models)

        let predicate = #Predicate<TestSwiftDataModel> { $0.value > 40 }
        let filtered = try storage.fetch(matching: predicate)

        #expect(filtered.count == 2)
    }
}

@Suite("SwiftData Repository Tests")
@MainActor
struct SwiftDataRepositoryTests {
    /// Creates a new in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Full CRUD flow")
    func fullCRUDFlow() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        // Create
        let model = TestSwiftDataModel(name: "CRUD Test", value: 42)
        let modelID = model.id
        try repository.save(model)

        // Read
        let fetched = try repository.fetch(id: modelID)
        #expect(fetched != nil)
        #expect(fetched?.name == "CRUD Test")

        // Update (in SwiftData, just modify and save again)
        if let existing = fetched {
            existing.name = "Updated"
            try repository.save(existing)
        }

        let updated = try repository.fetch(id: modelID)
        #expect(updated?.name == "Updated")

        // Delete
        try repository.delete(id: modelID)

        let deleted = try repository.fetch(id: modelID)
        #expect(deleted == nil)
    }

    @Test("Batch save operations")
    func batchSave() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        let models = (0 ..< 5).map { TestSwiftDataModel(name: "Item \($0)", value: $0) }
        try repository.saveAll(models)

        let all = try repository.fetchAll()
        #expect(all.count == 5)
    }

    @Test("Delete all entities")
    func deleteAll() throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        let models = [
            TestSwiftDataModel(name: "X", value: 1),
            TestSwiftDataModel(name: "Y", value: 2)
        ]

        try repository.saveAll(models)
        #expect(try repository.fetchAll().count == 2)

        try repository.deleteAll()
        #expect(try repository.fetchAll().isEmpty)
    }
}

// MARK: - Fetch by ID Tests

@Suite("SwiftData Storage Fetch by ID Tests")
@MainActor
struct SwiftDataStorageFetchByIDTests {
    /// Creates a new in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Fetch by ID returns correct entity")
    func fetchByIdReturnsCorrectEntity() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model1 = TestSwiftDataModel(name: "First", value: 100)
        let model2 = TestSwiftDataModel(name: "Second", value: 200)
        let model3 = TestSwiftDataModel(name: "Third", value: 300)

        try storage.saveAll([model1, model2, model3])

        // When
        let fetched = try storage.fetch(id: model2.id)

        // Then
        #expect(fetched != nil)
        #expect(fetched?.id == model2.id)
        #expect(fetched?.name == "Second")
        #expect(fetched?.value == 200)
    }

    @Test("Fetch by ID returns nil for non-existent ID")
    func fetchByIdReturnsNilForNonExistent() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model = TestSwiftDataModel(name: "Existing", value: 42)
        try storage.save(model)

        // When
        let nonExistentID = UUID()
        let fetched = try storage.fetch(id: nonExistentID)

        // Then
        #expect(fetched == nil)
    }

    @Test("Fetch by ID uses registered objects cache")
    func fetchByIdUsesCachedRegisteredObjects() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model = TestSwiftDataModel(name: "Cached", value: 42)
        let modelID = model.id

        try storage.save(model)

        // When - first fetch populates cache
        let firstFetch = try storage.fetch(id: modelID)
        // When - second fetch should use cache
        let secondFetch = try storage.fetch(id: modelID)

        // Then
        #expect(firstFetch != nil)
        #expect(secondFetch != nil)
        #expect(firstFetch === secondFetch) // Same object reference (from cache)
    }

    @Test("Fetch by ID removes deleted objects from cache")
    func fetchByIdRemovesDeletedFromCache() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let model = TestSwiftDataModel(name: "ToDelete", value: 42)
        let modelID = model.id

        try storage.save(model)
        _ = try storage.fetch(id: modelID) // Populate cache

        // When
        try storage.delete(id: modelID)
        let fetchedAfterDelete = try storage.fetch(id: modelID)

        // Then
        #expect(fetchedAfterDelete == nil)
    }
}

// MARK: - Prefetching Tests

@Suite("SwiftData Storage Prefetching Tests")
@MainActor
struct SwiftDataStoragePrefetchingTests {
    /// Creates a new in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Fetch all with empty prefetching returns all entities")
    func fetchAllWithEmptyPrefetching() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "A", value: 1),
            TestSwiftDataModel(name: "B", value: 2),
            TestSwiftDataModel(name: "C", value: 3)
        ]
        try storage.saveAll(models)

        // When - empty prefetching array
        let keyPaths: [PartialKeyPath<TestSwiftDataModel>] = []
        let results = try storage.fetchAll(prefetching: keyPaths)

        // Then
        #expect(results.count == 3)
    }

    @Test("Fetch with predicate and prefetching filters correctly")
    func fetchWithPredicateAndPrefetching() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "Low", value: 10),
            TestSwiftDataModel(name: "High", value: 100),
            TestSwiftDataModel(name: "Medium", value: 50)
        ]
        try storage.saveAll(models)

        // When
        let predicate = #Predicate<TestSwiftDataModel> { $0.value >= 50 }
        let keyPaths: [PartialKeyPath<TestSwiftDataModel>] = []
        let results = try storage.fetch(matching: predicate, prefetching: keyPaths)

        // Then
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.value >= 50 })
    }

    @Test("Full configuration fetch with sorting and limit")
    func fullConfigurationFetch() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = [
            TestSwiftDataModel(name: "A", value: 30),
            TestSwiftDataModel(name: "B", value: 10),
            TestSwiftDataModel(name: "C", value: 50),
            TestSwiftDataModel(name: "D", value: 20),
            TestSwiftDataModel(name: "E", value: 40)
        ]
        try storage.saveAll(models)

        // When - sort by value descending, limit to 3
        let sortDescriptors: [Foundation.SortDescriptor<TestSwiftDataModel>] = [
            Foundation.SortDescriptor(\.value, order: .reverse)
        ]
        let results = try storage.fetch(sortedBy: sortDescriptors, limit: 3)

        // Then
        #expect(results.count == 3)
        #expect(results[0].value == 50) // C
        #expect(results[1].value == 40) // E
        #expect(results[2].value == 30) // A
    }

    @Test("Full configuration fetch with predicate and offset")
    func fullConfigurationFetchWithOffset() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)

        let models = (1 ... 10).map { TestSwiftDataModel(name: "Item \($0)", value: $0) }
        try storage.saveAll(models)

        // When - values > 3, sorted, skip first 2, take 3
        let predicate = #Predicate<TestSwiftDataModel> { $0.value > 3 }
        let sortDescriptors: [Foundation.SortDescriptor<TestSwiftDataModel>] = [
            Foundation.SortDescriptor(\.value)
        ]
        let results = try storage.fetch(
            matching: predicate,
            sortedBy: sortDescriptors,
            limit: 3,
            offset: 2
        )

        // Then - should get values 6, 7, 8 (skipped 4, 5)
        #expect(results.count == 3)
        #expect(results[0].value == 6)
        #expect(results[1].value == 7)
        #expect(results[2].value == 8)
    }
}

// MARK: - Repository Prefetching Tests

@Suite("SwiftData Repository Prefetching Tests")
@MainActor
struct SwiftDataRepositoryPrefetchingTests {
    /// Creates a new in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Repository fetchAll with prefetching")
    func repositoryFetchAllWithPrefetching() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        let models = [
            TestSwiftDataModel(name: "X", value: 1),
            TestSwiftDataModel(name: "Y", value: 2)
        ]
        try repository.saveAll(models)

        // When
        let keyPaths: [PartialKeyPath<TestSwiftDataModel>] = []
        let results = try repository.fetchAll(prefetching: keyPaths)

        // Then
        #expect(results.count == 2)
    }

    @Test("Repository fetch with predicate and prefetching")
    func repositoryFetchWithPredicateAndPrefetching() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        let models = [
            TestSwiftDataModel(name: "Low", value: 5),
            TestSwiftDataModel(name: "High", value: 95)
        ]
        try repository.saveAll(models)

        // When
        let predicate = #Predicate<TestSwiftDataModel> { $0.value > 50 }
        let keyPaths: [PartialKeyPath<TestSwiftDataModel>] = []
        let results = try repository.fetch(matching: predicate, prefetching: keyPaths)

        // Then
        #expect(results.count == 1)
        #expect(results.first?.name == "High")
    }

    @Test("Repository full configuration fetch")
    func repositoryFullConfigurationFetch() throws {
        // Given
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let repository = SwiftDataRepository(storage: storage)

        let models = (1 ... 5).map { TestSwiftDataModel(name: "Item \($0)", value: $0 * 10) }
        try repository.saveAll(models)

        // When
        let sortDescriptors: [Foundation.SortDescriptor<TestSwiftDataModel>] = [
            Foundation.SortDescriptor(\.value, order: .reverse)
        ]
        let results = try repository.fetch(sortedBy: sortDescriptors, limit: 2)

        // Then
        #expect(results.count == 2)
        #expect(results[0].value == 50)
        #expect(results[1].value == 40)
    }
}
