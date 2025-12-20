import XCTest
@testable import ARCStorage

final class UserDefaultsStorageTests: XCTestCase {
    var storage: UserDefaultsStorage<SimpleTestModel>!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")
        storage = UserDefaultsStorage<SimpleTestModel>(
            userDefaults: userDefaults!,
            keyPrefix: "test"
        )
    }

    override func tearDown() async throws {
        userDefaults?.removePersistentDomain(forName: userDefaults.persistentDomainNames().first ?? "")
    }

    func testSaveAndFetch() async throws {
        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        let fetched = try await storage.fetch(id: model.id)

        XCTAssertEqual(fetched?.id, model.id)
        XCTAssertEqual(fetched?.data, model.data)
    }

    func testFetchAll() async throws {
        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        let fetched = try await storage.fetchAll()

        XCTAssertEqual(fetched.count, 2)
    }

    func testDelete() async throws {
        let model = SimpleTestModel.fixture1

        try await storage.save(model)
        try await storage.delete(id: model.id)

        let fetched = try await storage.fetch(id: model.id)
        XCTAssertNil(fetched)
    }

    func testDeleteAll() async throws {
        try await storage.save(SimpleTestModel.fixture1)
        try await storage.save(SimpleTestModel.fixture2)

        try await storage.deleteAll()

        let fetched = try await storage.fetchAll()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testUpdate() async throws {
        var model = SimpleTestModel.fixture1

        try await storage.save(model)

        model.data = "Updated Data"
        try await storage.save(model)

        let fetched = try await storage.fetch(id: model.id)
        XCTAssertEqual(fetched?.data, "Updated Data")
    }
}
