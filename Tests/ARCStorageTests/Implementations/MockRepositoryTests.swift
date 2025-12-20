import XCTest
@testable import ARCStorage

final class MockRepositoryTests: XCTestCase {
    var repository: MockRepository<TestModel>!

    override func setUp() async throws {
        repository = MockRepository<TestModel>()
    }

    func testSaveTracking() async throws {
        let model = TestModel.fixture1

        try await repository.save(model)

        let callCount = await repository.saveCallCount
        let lastSaved = await repository.lastSavedEntity

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(lastSaved?.id, model.id)
    }

    func testFetchAllTracking() async throws {
        await repository.setMockEntities(TestModel.allFixtures)

        let fetched = try await repository.fetchAll()
        let callCount = await repository.fetchAllCallCount

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(fetched.count, 3)
    }

    func testFetchTracking() async throws {
        await repository.setMockEntities([TestModel.fixture1])

        let model = try await repository.fetch(id: TestModel.fixture1.id)
        let callCount = await repository.fetchCallCount
        let lastID = await repository.lastAccessedID

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(lastID, TestModel.fixture1.id)
        XCTAssertNotNil(model)
    }

    func testDeleteTracking() async throws {
        await repository.setMockEntities([TestModel.fixture1])

        try await repository.delete(id: TestModel.fixture1.id)

        let callCount = await repository.deleteCallCount
        let lastID = await repository.lastAccessedID

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(lastID, TestModel.fixture1.id)
    }

    func testErrorSimulation() async {
        await repository.setShouldThrowError(.saveFailed(underlying: NSError(domain: "test", code: 1)))

        do {
            try await repository.save(TestModel.fixture1)
            XCTFail("Should have thrown error")
        } catch let error as StorageError {
            if case .saveFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func testReset() async {
        await repository.setMockEntities(TestModel.allFixtures)
        try? await repository.save(TestModel.fixture1)

        await repository.reset()

        let entities = await repository.mockEntities
        let callCount = await repository.saveCallCount

        XCTAssertTrue(entities.isEmpty)
        XCTAssertEqual(callCount, 0)
    }
}

extension MockRepository {
    func setMockEntities(_ entities: [Entity]) async {
        mockEntities = entities
    }

    func setShouldThrowError(_ error: StorageError?) async {
        shouldThrowError = error
    }
}
