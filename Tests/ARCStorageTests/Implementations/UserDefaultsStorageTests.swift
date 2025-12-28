import Foundation
import Testing
@testable import ARCStorage

@Suite("UserDefaultsStorage Tests")
struct UserDefaultsStorageTests {

    private func makeStorage() -> (storage: UserDefaultsStorage<SimpleTestModel>, cleanup: () -> Void) {
        let suiteName = "test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let storage = UserDefaultsStorage<SimpleTestModel>(
            userDefaults: userDefaults,
            keyPrefix: "test"
        )
        let cleanup = {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        return (storage, cleanup)
    }

    @Test("Save and fetch works correctly")
    func saveAndFetch_worksCorrectly() async throws {
        let (storage, cleanup) = makeStorage()
        defer { cleanup() }

        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        #expect(fetched?.id == model.id)
        #expect(fetched?.data == model.data)
    }

    @Test("Fetch all returns all saved entities")
    func fetchAll_returnsAllSavedEntities() async throws {
        let (storage, cleanup) = makeStorage()
        defer { cleanup() }

        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        let fetched = try await storage.fetchAll()

        #expect(fetched.count == 2)
    }

    @Test("Delete removes entity")
    func delete_removesEntity() async throws {
        let (storage, cleanup) = makeStorage()
        defer { cleanup() }

        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        try await storage.delete(id: model.id)

        let fetched = try await storage.fetch(id: model.id)
        #expect(fetched == nil)
    }

    @Test("Delete all clears storage")
    func deleteAll_clearsStorage() async throws {
        let (storage, cleanup) = makeStorage()
        defer { cleanup() }

        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        try await storage.deleteAll()

        let fetched = try await storage.fetchAll()
        #expect(fetched.isEmpty)
    }

    @Test("Update replaces existing entity")
    func update_replacesExistingEntity() async throws {
        let (storage, cleanup) = makeStorage()
        defer { cleanup() }

        var model = SimpleTestModel.fixture1

        try await storage.save(model)

        model.data = "Updated Data"
        try await storage.save(model)

        let fetched = try await storage.fetch(id: model.id)
        #expect(fetched?.data == "Updated Data")
    }
}
