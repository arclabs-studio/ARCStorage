import XCTest
@testable import ARCStorage

final class InMemoryStorageTests: XCTestCase {
    var storage: InMemoryStorage<TestModel>!

    override func setUp() async throws {
        storage = InMemoryStorage<TestModel>()
    }

    func testSaveAndFetch() async throws {
        let model = TestModel.fixture1

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        XCTAssertEqual(fetched?.id, model.id)
        XCTAssertEqual(fetched?.name, model.name)
        XCTAssertEqual(fetched?.value, model.value)
    }

    func testFetchAll() async throws {
        let models = TestModel.allFixtures

        try await storage.saveAll(models)
        let fetched = try await storage.fetchAll()

        XCTAssertEqual(fetched.count, 3)
    }

    func testDelete() async throws {
        let model = TestModel.fixture1

        try await storage.save(model)
        try await storage.delete(id: model.id)

        let fetched = try await storage.fetch(id: model.id)
        XCTAssertNil(fetched)
    }

    func testDeleteNonExistent() async {
        let nonExistentID = UUID()

        do {
            try await storage.delete(id: nonExistentID)
            XCTFail("Should have thrown notFound error")
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

    func testDeleteAll() async throws {
        try await storage.saveAll(TestModel.allFixtures)

        try await storage.deleteAll()

        let fetched = try await storage.fetchAll()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testFetchWithPredicate() async throws {
        try await storage.saveAll(TestModel.allFixtures)

        let predicate = #Predicate<TestModel> { $0.value > 150 }
        let fetched = try await storage.fetch(matching: predicate)

        XCTAssertEqual(fetched.count, 2) // fixture2 and fixture3
    }

    func testTransaction() async throws {
        let model1 = TestModel.fixture1
        let model2 = TestModel.fixture2

        try await storage.performTransaction {
            try await storage.save(model1)
            try await storage.save(model2)
        }

        let fetched = try await storage.fetchAll()
        XCTAssertEqual(fetched.count, 2)
    }

    func testTransactionRollback() async {
        let model1 = TestModel.fixture1

        do {
            try await storage.performTransaction {
                try await storage.save(model1)
                throw NSError(domain: "test", code: 1)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }

        // Changes should be rolled back
        let fetched = try? await storage.fetchAll()
        XCTAssertEqual(fetched?.count, 0)
    }

    func testConcurrentAccess() async throws {
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let model = TestModel(id: UUID(), name: "Test \(i)", value: i)
                    try? await self.storage.save(model)
                }
            }
        }

        let fetched = try await storage.fetchAll()
        XCTAssertEqual(fetched.count, iterations)
    }
}
