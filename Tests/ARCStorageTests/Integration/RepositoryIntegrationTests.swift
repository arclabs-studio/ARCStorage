import XCTest
@testable import ARCStorage

final class RepositoryIntegrationTests: XCTestCase {
    var repository: InMemoryRepository<TestModel>!

    override func setUp() async throws {
        repository = InMemoryRepository<TestModel>(cachePolicy: .default)
    }

    func testFullCRUDFlow() async throws {
        let model = TestModel.fixture1

        // Create
        try await repository.save(model)

        // Read
        let fetched = try await repository.fetch(id: model.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, model.id)

        // Update
        var updated = model
        updated.name = "Updated Name"
        try await repository.save(updated)

        let fetchedAgain = try await repository.fetch(id: model.id)
        XCTAssertEqual(fetchedAgain?.name, "Updated Name")

        // Delete
        try await repository.delete(id: model.id)

        let fetchedAfterDelete = try await repository.fetch(id: model.id)
        XCTAssertNil(fetchedAfterDelete)
    }

    func testCacheIntegration() async throws {
        let model = TestModel.fixture1

        // Save and fetch (populates cache)
        try await repository.save(model)
        let fetched1 = try await repository.fetch(id: model.id)
        XCTAssertNotNil(fetched1)

        // Fetch again (should hit cache)
        let fetched2 = try await repository.fetch(id: model.id)
        XCTAssertNotNil(fetched2)
        XCTAssertEqual(fetched1?.id, fetched2?.id)
    }

    func testCacheInvalidation() async throws {
        let model = TestModel.fixture1

        try await repository.save(model)
        _ = try await repository.fetch(id: model.id) // Populate cache

        await repository.invalidateCache()

        // Should fetch from storage, not cache
        let fetched = try await repository.fetch(id: model.id)
        XCTAssertNotNil(fetched)
    }

    func testBatchOperations() async throws {
        let models = TestModel.allFixtures

        // Save all
        for model in models {
            try await repository.save(model)
        }

        // Fetch all
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, models.count)

        // Delete all
        for model in models {
            try await repository.delete(id: model.id)
        }

        let fetchedAfterDelete = try await repository.fetchAll()
        XCTAssertTrue(fetchedAfterDelete.isEmpty)
    }

    func testConcurrentOperations() async throws {
        let iterations = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let model = TestModel(id: UUID(), name: "Test \(i)", value: i)
                    try? await self.repository.save(model)
                }
            }
        }

        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, iterations)
    }

    func testErrorHandling() async {
        // Try to delete non-existent entity
        do {
            try await repository.delete(id: UUID())
            XCTFail("Should have thrown error")
        } catch let error as StorageError {
            if case .notFound = error {
                // Success
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
}
