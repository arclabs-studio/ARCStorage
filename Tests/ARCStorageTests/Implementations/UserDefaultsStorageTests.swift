import Foundation
import Testing
@testable import ARCStorage

struct UserDefaultsStorageTests {
    @Test("Save and fetch works correctly") func saveAndFetch_worksCorrectly() async throws {
        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: .standard,
                                                           keyPrefix: "test.\(UUID().uuidString)")
        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        #expect(fetched?.id == model.id)
        #expect(fetched?.data == model.data)

        // Cleanup
        try await storage.deleteAll()
    }

    @Test("Fetch all returns all saved entities") func fetchAll_returnsAllSavedEntities() async throws {
        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: .standard,
                                                           keyPrefix: "test.\(UUID().uuidString)")

        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        let fetched = try await storage.fetchAll()

        #expect(fetched.count == 2)

        // Cleanup
        try await storage.deleteAll()
    }

    @Test("Delete removes entity") func delete_removesEntity() async throws {
        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: .standard,
                                                           keyPrefix: "test.\(UUID().uuidString)")
        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        try await storage.delete(id: model.id)

        let fetched = try await storage.fetch(id: model.id)
        #expect(fetched == nil)
    }

    @Test("Delete all clears storage") func deleteAll_clearsStorage() async throws {
        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: .standard,
                                                           keyPrefix: "test.\(UUID().uuidString)")

        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        try await storage.deleteAll()

        let fetched = try await storage.fetchAll()
        #expect(fetched.isEmpty)
    }

    @Test("Update replaces existing entity") func update_replacesExistingEntity() async throws {
        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: .standard,
                                                           keyPrefix: "test.\(UUID().uuidString)")
        var model = SimpleTestModel.fixture1

        try await storage.save(model)

        model.data = "Updated Data"
        try await storage.save(model)

        let fetched = try await storage.fetch(id: model.id)
        #expect(fetched?.data == "Updated Data")

        // Cleanup
        try await storage.deleteAll()
    }

    @Test("fetchAll skips corrupted entries and returns valid ones")
    func fetchAll_skipsCorruptedEntries() async throws {
        // Given — use a dedicated suite to avoid sending risks with .standard
        let prefix = "test.\(UUID().uuidString)"
        let suiteName = "ARCStorage.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))

        // Inject garbage data before handing defaults to actor
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "\(prefix).corrupted-key")

        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: defaults, keyPrefix: prefix)
        try await storage.save(SimpleTestModel.fixture1)

        // When
        let fetched = try await storage.fetchAll()

        // Then — valid entity returned, corrupted one skipped
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == SimpleTestModel.fixture1.id)

        // Cleanup
        try await storage.deleteAll()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("fetchAllWithDiagnostics reports corruption count")
    func fetchAllWithDiagnostics_reportsCorruption() async throws {
        // Given — use a dedicated suite to avoid sending risks with .standard
        let prefix = "test.\(UUID().uuidString)"
        let suiteName = "ARCStorage.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))

        // Inject corrupted entries before handing defaults to actor
        defaults.set(Data([0xFF]), forKey: "\(prefix).bad1")
        defaults.set(Data([0xFE]), forKey: "\(prefix).bad2")

        let storage = UserDefaultsStorage<SimpleTestModel>(userDefaults: defaults, keyPrefix: prefix)
        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        // When
        let result = try await storage.fetchAllWithDiagnostics()

        // Then
        #expect(result.entities.count == 2)
        #expect(result.corruptedCount == 2)
        #expect(result.hasCorruption == true)

        // Cleanup
        try await storage.deleteAll()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
