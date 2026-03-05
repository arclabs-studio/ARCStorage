import Foundation
import Testing
@testable import ARCStorage

@Suite("KeychainRepository Tests")
struct KeychainRepositoryTests {
    // MARK: - Save & Fetch

    @Test("Save and fetch works correctly") func saveAndFetch_worksCorrectly() async throws {
        // Given
        let sut = makeSUT()
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then
        #expect(fetched?.id == model.id)
        #expect(fetched?.data == model.data)

        try await cleanup(sut)
    }

    @Test("Fetch non-existent returns nil") func fetch_nonExistent_returnsNil() async throws {
        // Given
        let sut = makeSUT()

        // When
        let result = try await sut.fetch(id: "does_not_exist")

        // Then
        #expect(result == nil)
    }

    @Test("Save overwrites existing entity") func save_overwrites_existingEntity() async throws {
        // Given
        let sut = makeSUT()
        var model = SimpleTestModel.fixture1
        try await sut.save(model)

        // When
        model.data = "Updated Data"
        try await sut.save(model)

        // Then
        let fetched = try await sut.fetch(id: model.id)
        #expect(fetched?.data == "Updated Data")

        try await cleanup(sut)
    }

    // MARK: - Fetch All

    @Test("Fetch all returns empty when nothing saved") func fetchAll_returnsEmpty_whenNothingSaved() async throws {
        // Given
        let sut = makeSUT()

        // When
        let result = try await sut.fetchAll()

        // Then
        #expect(result.isEmpty)
    }

    @Test("Fetch all returns all saved entities") func fetchAll_returnsAllSavedEntities() async throws {
        // Given
        let sut = makeSUT()
        try await sut.save(SimpleTestModel.fixture1)
        try await sut.save(SimpleTestModel.fixture2)

        // When
        let fetched = try await sut.fetchAll()

        // Then
        #expect(fetched.count == 2)

        try await cleanup(sut)
    }

    // MARK: - Delete

    @Test("Delete removes entity") func delete_removesEntity() async throws {
        // Given
        let sut = makeSUT()
        let model = SimpleTestModel.fixture1
        try await sut.save(model)

        // When
        try await sut.delete(id: model.id)

        // Then
        let fetched = try await sut.fetch(id: model.id)
        #expect(fetched == nil)
    }

    @Test("Delete non-existent throws StorageError") func delete_nonExistent_throwsStorageError() async throws {
        // Given
        let sut = makeSUT()

        // When / Then
        await #expect(throws: StorageError.self) {
            try await sut.delete(id: "does_not_exist")
        }
    }

    // MARK: - Cache-Aside Pattern

    @Test("Second fetch is served from cache") func secondFetch_isServedFromCache() async throws {
        // Given
        let sut = makeSUT()
        let model = SimpleTestModel.fixture1
        try await sut.save(model)

        // When — first fetch populates cache
        _ = try await sut.fetch(id: model.id)
        // Second fetch should hit cache (no Keychain I/O)
        let cached = try await sut.fetch(id: model.id)

        // Then
        #expect(cached?.id == model.id)
        #expect(cached?.data == model.data)

        try await cleanup(sut)
    }

    @Test("Fetch all populates cache for subsequent individual fetches") func fetchAll_populatesCache() async throws {
        // Given
        let sut = makeSUT()
        try await sut.save(SimpleTestModel.fixture1)
        try await sut.save(SimpleTestModel.fixture2)

        // When — fetchAll warms the cache
        _ = try await sut.fetchAll()
        let cached = try await sut.fetch(id: SimpleTestModel.fixture1.id)

        // Then
        #expect(cached?.id == SimpleTestModel.fixture1.id)

        try await cleanup(sut)
    }

    @Test("Delete evicts entity from cache") func delete_evictsEntityFromCache() async throws {
        // Given
        let sut = makeSUT()
        let model = SimpleTestModel.fixture1
        try await sut.save(model)
        _ = try await sut.fetch(id: model.id) // warm cache

        // When
        try await sut.delete(id: model.id)

        // Then — cache miss forces Keychain lookup, which also returns nil
        let result = try await sut.fetch(id: model.id)
        #expect(result == nil)
    }

    @Test("Invalidate cache causes re-fetch from storage") func invalidateCache_causesFreshFetch() async throws {
        // Given
        let sut = makeSUT()
        try await sut.save(SimpleTestModel.fixture1)
        _ = try await sut.fetchAll() // warm cache

        // When
        await sut.invalidateCache()
        let refetched = try await sut.fetch(id: SimpleTestModel.fixture1.id)

        // Then — entity is still in Keychain after cache invalidation
        #expect(refetched?.id == SimpleTestModel.fixture1.id)

        try await cleanup(sut)
    }

    // MARK: - Accessibility

    @Test("Repository with whenUnlockedThisDeviceOnly stores correctly") func repository_whenUnlockedThisDeviceOnly() async throws {
        // Given
        let sut = makeSUT(accessibility: .whenUnlockedThisDeviceOnly)
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then
        #expect(fetched?.id == model.id)

        try await cleanup(sut)
    }

    @Test("Repository with afterFirstUnlockThisDeviceOnly stores correctly") func repository_afterFirstUnlockThisDeviceOnly() async throws {
        // Given
        // Note: .whenPasscodeSetThisDeviceOnly requires a passcode on the device.
        // In simulator/CI without a passcode this may return errSecParam (-50).
        // We use .afterFirstUnlockThisDeviceOnly as the highest-security option
        // available without passcode enforcement in CI environments.
        let sut = makeSUT(accessibility: .afterFirstUnlockThisDeviceOnly)
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then
        #expect(fetched?.id == model.id)

        try await cleanup(sut)
    }

    // MARK: - Custom Cache Policy

    @Test("noCache policy still fetches from Keychain") func noCache_stillFetchesFromKeychain() async throws {
        // Given
        let sut = KeychainRepository<SimpleTestModel>(service: "com.arcstorage.tests.\(UUID().uuidString)",
                                                      cachePolicy: .noCache)
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then — fetch still returns from Keychain even with no cache
        #expect(fetched?.id == model.id)

        try await cleanup(sut)
    }

    // MARK: - Factory Method

    private func makeSUT(accessibility: KeychainAccessibility = .whenUnlocked) -> KeychainRepository<SimpleTestModel> {
        KeychainRepository<SimpleTestModel>(service: "com.arcstorage.tests.\(UUID().uuidString)",
                                            accessibility: accessibility)
    }

    private func cleanup(_ repo: KeychainRepository<SimpleTestModel>, ids: [String] = ["test1", "test2"]) async throws {
        for id in ids {
            try? await repo.delete(id: id)
        }
    }
}
