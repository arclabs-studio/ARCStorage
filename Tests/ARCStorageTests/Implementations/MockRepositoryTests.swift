import Testing
@testable import ARCStorage

@Suite("MockRepository Tests")
struct MockRepositoryTests {

    @Test("Save tracking records call")
    func saveTracking_recordsCall() async throws {
        let repository = MockRepository<TestModel>()
        let model = TestModel.fixture1

        try await repository.save(model)

        let callCount = await repository.saveCallCount
        let lastSaved = await repository.lastSavedEntity

        #expect(callCount == 1)
        #expect(lastSaved?.id == model.id)
    }

    @Test("Fetch all tracking records call")
    func fetchAllTracking_recordsCall() async throws {
        let repository = MockRepository<TestModel>()
        await repository.setMockEntities(TestModel.allFixtures)

        let fetched = try await repository.fetchAll()
        let callCount = await repository.fetchAllCallCount

        #expect(callCount == 1)
        #expect(fetched.count == 3)
    }

    @Test("Fetch tracking records call and ID")
    func fetchTracking_recordsCallAndID() async throws {
        let repository = MockRepository<TestModel>()
        await repository.setMockEntities([TestModel.fixture1])

        let model = try await repository.fetch(id: TestModel.fixture1.id)
        let callCount = await repository.fetchCallCount
        let lastID = await repository.lastAccessedID

        #expect(callCount == 1)
        #expect(lastID == TestModel.fixture1.id)
        #expect(model != nil)
    }

    @Test("Delete tracking records call and ID")
    func deleteTracking_recordsCallAndID() async throws {
        let repository = MockRepository<TestModel>()
        await repository.setMockEntities([TestModel.fixture1])

        try await repository.delete(id: TestModel.fixture1.id)

        let callCount = await repository.deleteCallCount
        let lastID = await repository.lastAccessedID

        #expect(callCount == 1)
        #expect(lastID == TestModel.fixture1.id)
    }

    @Test("Error simulation throws configured error")
    func errorSimulation_throwsConfiguredError() async throws {
        let repository = MockRepository<TestModel>()
        await repository.setShouldThrowError(.saveFailed(underlying: NSError(domain: "test", code: 1)))

        await #expect(throws: StorageError.self) {
            try await repository.save(TestModel.fixture1)
        }
    }

    @Test("Reset clears all state")
    func reset_clearsAllState() async throws {
        let repository = MockRepository<TestModel>()
        await repository.setMockEntities(TestModel.allFixtures)
        try? await repository.save(TestModel.fixture1)

        await repository.reset()

        let entities = await repository.mockEntities
        let callCount = await repository.saveCallCount

        #expect(entities.isEmpty)
        #expect(callCount == 0)
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
