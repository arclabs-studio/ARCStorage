import Foundation
import SwiftData
import Testing
@testable import ARCStorage

/// Test model that conforms to SwiftDataEntity.
/// This model does NOT conform to Sendable or Codable, demonstrating
/// Swift 6 strict concurrency compatibility.
@Model
final class TestSwiftDataModel: SwiftDataEntity {
    var id: UUID
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
            TestSwiftDataModel(name: "Batch3", value: 30),
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
            TestSwiftDataModel(name: "B", value: 2),
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
            TestSwiftDataModel(name: "Medium", value: 50),
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
            TestSwiftDataModel(name: "Y", value: 2),
        ]

        try repository.saveAll(models)
        #expect(try repository.fetchAll().count == 2)

        try repository.deleteAll()
        #expect(try repository.fetchAll().isEmpty)
    }
}
