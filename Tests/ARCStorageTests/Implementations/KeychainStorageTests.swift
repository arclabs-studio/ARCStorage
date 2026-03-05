import Foundation
import Testing
@testable import ARCStorage

@Suite("KeychainStorage Tests")
struct KeychainStorageTests {
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

        try await sut.deleteAll()
    }

    @Test("Fetch non-existent returns nil") func fetchNonExistent_returnsNil() async throws {
        // Given
        let sut = makeSUT()

        // When
        let result = try await sut.fetch(id: "does_not_exist")

        // Then
        #expect(result == nil)
    }

    @Test("Save all persists multiple entities") func saveAll_persistsMultipleEntities() async throws {
        // Given
        let sut = makeSUT()

        // When
        try await sut.saveAll([SimpleTestModel.fixture1, SimpleTestModel.fixture2])
        let fetched = try await sut.fetchAll()

        // Then
        #expect(fetched.count == 2)

        try await sut.deleteAll()
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

        try await sut.deleteAll()
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

        try await sut.deleteAll()
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

    @Test("Delete non-existent throws entityNotFound") func delete_nonExistent_throwsEntityNotFound() async throws {
        // Given
        let sut = makeSUT()

        // When / Then
        await #expect(throws: StorageError.self) {
            try await sut.delete(id: "does_not_exist")
        }
    }

    @Test("Delete all clears all entities") func deleteAll_clearsAllEntities() async throws {
        // Given
        let sut = makeSUT()
        try await sut.saveAll([SimpleTestModel.fixture1, SimpleTestModel.fixture2])

        // When
        try await sut.deleteAll()

        // Then
        let fetched = try await sut.fetchAll()
        #expect(fetched.isEmpty)
    }

    @Test("Delete all is idempotent on empty keychain") func deleteAll_isIdempotent_onEmpty() async throws {
        // Given
        let sut = makeSUT()

        // When / Then — should not throw
        try await sut.deleteAll()
    }

    // MARK: - Fetch with Predicate

    @Test("Fetch with predicate filters correctly") func fetchWithPredicate_filtersCorrectly() async throws {
        // Given
        let sut = makeSUT()
        try await sut.saveAll([SimpleTestModel.fixture1, SimpleTestModel.fixture2])

        // When
        let all = try await sut.fetchAll()
        let filtered = all.filter { $0.data == "Data 1" }

        // Then
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "test1")

        try await sut.deleteAll()
    }

    // MARK: - Transaction

    @Test("Transaction commits on success") func transaction_commitsOnSuccess() async throws {
        // Given
        let sut = makeSUT()

        // When
        try await sut.performTransaction {
            try await sut.save(SimpleTestModel.fixture1)
            try await sut.save(SimpleTestModel.fixture2)
        }

        // Then
        let fetched = try await sut.fetchAll()
        #expect(fetched.count == 2)

        try await sut.deleteAll()
    }

    @Test("Transaction wraps error in transactionFailed") func transaction_wrapsError_inTransactionFailed() async throws {
        // Given
        let sut = makeSUT()

        // When / Then
        do {
            try await sut.performTransaction {
                throw NSError(domain: "test", code: 42)
            }
            Issue.record("Expected transaction to throw")
        } catch let error as StorageError {
            if case .transactionFailed = error {
                // Expected
            } else {
                Issue.record("Expected transactionFailed, got \(error)")
            }
        }
    }

    // MARK: - Accessibility

    @Test("Storage with whenUnlockedThisDeviceOnly saves and fetches") func accessibility_whenUnlockedThisDeviceOnly() async throws {
        // Given
        let sut = makeSUT(accessibility: .whenUnlockedThisDeviceOnly)
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then
        #expect(fetched?.id == model.id)

        try await sut.deleteAll()
    }

    @Test("Storage with afterFirstUnlock saves and fetches") func accessibility_afterFirstUnlock() async throws {
        // Given
        let sut = makeSUT(accessibility: .afterFirstUnlock)
        let model = SimpleTestModel.fixture1

        // When
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)

        // Then
        #expect(fetched?.id == model.id)

        try await sut.deleteAll()
    }

    // MARK: - Service Isolation

    @Test("Different services store independently") func differentServices_storeIndependently() async throws {
        // Given
        let uniquePrefix = UUID().uuidString
        let sut1 = KeychainStorage<SimpleTestModel>(service: "com.test.service1.\(uniquePrefix)")
        let sut2 = KeychainStorage<SimpleTestModel>(service: "com.test.service2.\(uniquePrefix)")
        let model = SimpleTestModel(id: "shared_id", data: "service1_data")

        // When
        try await sut1.save(model)
        let fromService1 = try await sut1.fetch(id: "shared_id")
        let fromService2 = try await sut2.fetch(id: "shared_id")

        // Then
        #expect(fromService1?.data == "service1_data")
        #expect(fromService2 == nil)

        try await sut1.deleteAll()
    }

    // MARK: - Factory Method

    private func makeSUT(accessibility: KeychainAccessibility = .whenUnlocked) -> KeychainStorage<SimpleTestModel> {
        KeychainStorage<SimpleTestModel>(service: "com.arcstorage.tests.\(UUID().uuidString)",
                                         accessibility: accessibility)
    }
}
