import Testing
@testable import ARCStorage

@Suite("Repository Integration Tests")
struct RepositoryIntegrationTests {

    @Test("Full CRUD flow completes successfully")
    func fullCRUDFlow_completesSuccessfully() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)
        let model = TestModel.fixture1

        // Create
        try await repository.save(model)

        // Read
        let fetched = try await repository.fetch(id: model.id)
        #expect(fetched != nil)
        #expect(fetched?.id == model.id)

        // Update
        var updated = model
        updated.name = "Updated Name"
        try await repository.save(updated)

        let fetchedAgain = try await repository.fetch(id: model.id)
        #expect(fetchedAgain?.name == "Updated Name")

        // Delete
        try await repository.delete(id: model.id)

        let fetchedAfterDelete = try await repository.fetch(id: model.id)
        #expect(fetchedAfterDelete == nil)
    }

    @Test("Cache integration populates on fetch")
    func cacheIntegration_populatesOnFetch() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)
        let model = TestModel.fixture1

        // Save and fetch (populates cache)
        try await repository.save(model)
        let fetched1 = try await repository.fetch(id: model.id)
        #expect(fetched1 != nil)

        // Fetch again (should hit cache)
        let fetched2 = try await repository.fetch(id: model.id)
        #expect(fetched2 != nil)
        #expect(fetched1?.id == fetched2?.id)
    }

    @Test("Cache invalidation clears cache")
    func cacheInvalidation_clearsCache() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)
        let model = TestModel.fixture1

        try await repository.save(model)
        _ = try await repository.fetch(id: model.id) // Populate cache

        await repository.invalidateCache()

        // Should fetch from storage, not cache
        let fetched = try await repository.fetch(id: model.id)
        #expect(fetched != nil)
    }

    @Test("Batch operations work correctly")
    func batchOperations_workCorrectly() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)
        let models = TestModel.allFixtures

        // Save all
        for model in models {
            try await repository.save(model)
        }

        // Fetch all
        let fetched = try await repository.fetchAll()
        #expect(fetched.count == models.count)

        // Delete all
        for model in models {
            try await repository.delete(id: model.id)
        }

        let fetchedAfterDelete = try await repository.fetchAll()
        #expect(fetchedAfterDelete.isEmpty)
    }

    @Test("Concurrent operations are thread-safe")
    func concurrentOperations_areThreadSafe() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)
        let iterations = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let model = TestModel(id: UUID(), name: "Test \(i)", value: i)
                    try? await repository.save(model)
                }
            }
        }

        let fetched = try await repository.fetchAll()
        #expect(fetched.count == iterations)
    }

    @Test("Delete non-existent entity throws notFound error")
    func deleteNonExistent_throwsNotFoundError() async throws {
        let repository = InMemoryRepository<TestModel>(cachePolicy: .default)

        await #expect(throws: StorageError.self) {
            try await repository.delete(id: UUID())
        }
    }
}
