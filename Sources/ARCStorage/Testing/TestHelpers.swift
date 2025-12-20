import Foundation

#if DEBUG

/// Test fixtures and utilities for ARCStorage testing.
///
/// This file contains helper types and functions for creating
/// test data and validating storage operations.

/// Sample test model for demonstrations and tests.
public struct TestModel: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var value: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        value: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.createdAt = createdAt
    }
}

extension TestModel {
    /// Predefined test fixtures.
    public static var fixture1: TestModel {
        TestModel(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test 1",
            value: 100
        )
    }

    public static var fixture2: TestModel {
        TestModel(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Test 2",
            value: 200
        )
    }

    public static var fixture3: TestModel {
        TestModel(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Test 3",
            value: 300
        )
    }

    public static var allFixtures: [TestModel] {
        [fixture1, fixture2, fixture3]
    }
}

/// Simple test model with String ID for UserDefaults/Keychain tests.
public struct SimpleTestModel: Codable, Identifiable, Sendable {
    public let id: String
    public var data: String

    public init(id: String, data: String) {
        self.id = id
        self.data = data
    }
}

extension SimpleTestModel {
    public static var fixture1: SimpleTestModel {
        SimpleTestModel(id: "test1", data: "Data 1")
    }

    public static var fixture2: SimpleTestModel {
        SimpleTestModel(id: "test2", data: "Data 2")
    }
}

/// Utilities for testing.
public enum TestHelpers {
    /// Creates a temporary directory for testing.
    public static func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }

    /// Cleans up a temporary directory.
    public static func cleanupTemporaryDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Waits for an async condition to be true.
    public static func wait(
        timeout: TimeInterval = 1.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        throw TestError.timeout
    }
}

/// Errors that can occur during testing.
public enum TestError: Error {
    case timeout
    case unexpectedValue
    case setupFailed
}

#endif
