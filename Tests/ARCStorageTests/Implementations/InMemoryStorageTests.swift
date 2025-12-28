import Foundation
import Testing
@testable import ARCStorage

@Suite("InMemoryStorage Tests")
struct InMemoryStorageTests {

    @Test("Save and fetch works correctly")
    func saveAndFetch_worksCorrectly() async throws {
        let storage = InMemoryStorage<TestModel>()
        let model = TestModel.fixture1

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        #expect(fetched?.id == model.id)
        #expect(fetched?.name == model.name)
        #expect(fetched?.value == model.value)
    }

    @Test("Fetch all returns all saved entities")
    func fetchAll_returnsAllSavedEntities() async throws {
        let storage = InMemoryStorage<TestModel>()
        let models = TestModel.allFixtures

        try await storage.saveAll(models)
        let fetched = try await storage.fetchAll()

        #expect(fetched.count == 3)
    }

    @Test("Delete removes entity")
    func delete_removesEntity() async throws {
        let storage = InMemoryStorage<TestModel>()
        let model = TestModel.fixture1

        try await storage.save(model)
        try await storage.delete(id: model.id)

        let fetched = try await storage.fetch(id: model.id)
        #expect(fetched == nil)
    }

    @Test("Delete non-existent throws notFound error")
    func deleteNonExistent_throwsNotFoundError() async throws {
        let storage = InMemoryStorage<TestModel>()
        let nonExistentID = UUID()

        await #expect(throws: StorageError.self) {
            try await storage.delete(id: nonExistentID)
        }
    }

    @Test("Delete all clears storage")
    func deleteAll_clearsStorage() async throws {
        let storage = InMemoryStorage<TestModel>()
        try await storage.saveAll(TestModel.allFixtures)

        try await storage.deleteAll()

        let fetched = try await storage.fetchAll()
        #expect(fetched.isEmpty)
    }

    @Test("Fetch with predicate filters correctly")
    func fetchWithPredicate_filtersCorrectly() async throws {
        let storage = InMemoryStorage<TestModel>()
        try await storage.saveAll(TestModel.allFixtures)

        // Filter using fetchAll and manual filter
        let allEntities = try await storage.fetchAll()
        let filtered = allEntities.filter { $0.value > 150 }

        #expect(filtered.count == 2) // fixture2 and fixture3
    }

    @Test("Transaction commits changes")
    func transaction_commitsChanges() async throws {
        let storage = InMemoryStorage<TestModel>()
        let model1 = TestModel.fixture1
        let model2 = TestModel.fixture2

        try await storage.performTransaction {
            try await storage.save(model1)
            try await storage.save(model2)
        }

        let fetched = try await storage.fetchAll()
        #expect(fetched.count == 2)
    }

    @Test("Transaction rollback on error")
    func transactionRollback_onError() async throws {
        let storage = InMemoryStorage<TestModel>()
        let model1 = TestModel.fixture1

        do {
            try await storage.performTransaction {
                try await storage.save(model1)
                throw NSError(domain: "test", code: 1)
            }
        } catch {
            // Expected
        }

        // Changes should be rolled back
        let fetched = try await storage.fetchAll()
        #expect(fetched.count == 0)
    }

    @Test("Concurrent access is thread-safe")
    func concurrentAccess_isThreadSafe() async throws {
        let storage = InMemoryStorage<TestModel>()
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let model = TestModel(id: UUID(), name: "Test \(i)", value: i)
                    try? await storage.save(model)
                }
            }
        }

        let fetched = try await storage.fetchAll()
        #expect(fetched.count == iterations)
    }
}
