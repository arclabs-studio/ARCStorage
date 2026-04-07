import Foundation
import SwiftData
import Testing
@testable import ARCStorage

@MainActor
struct SwiftDataChangeMonitorTests {
    // MARK: Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([TestSwiftDataModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: Tests

    @Test("Monitor yields after save") func yieldsAfterSave() async throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let monitor = SwiftDataChangeMonitor(modelContainer: container)

        var yieldCount = 0

        let observerTask = Task { @MainActor in
            for await _ in monitor.changes() {
                yieldCount += 1
                if yieldCount >= 1 { break }
            }
        }

        // Give the observer task a moment to start listening
        await Task.yield()

        let model = TestSwiftDataModel(name: "Test", value: 1)
        try storage.save(model)

        // Allow notification to propagate
        try await Task.sleep(for: .milliseconds(100))

        observerTask.cancel()

        #expect(yieldCount == 1)
    }

    @Test("Monitor yields once per save") func yieldsOncePerSave() async throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let monitor = SwiftDataChangeMonitor(modelContainer: container)

        var yieldCount = 0

        let observerTask = Task { @MainActor in
            for await _ in monitor.changes() {
                yieldCount += 1
                if yieldCount >= 3 { break }
            }
        }

        await Task.yield()

        try storage.save(TestSwiftDataModel(name: "First", value: 1))
        try storage.save(TestSwiftDataModel(name: "Second", value: 2))
        try storage.save(TestSwiftDataModel(name: "Third", value: 3))

        try await Task.sleep(for: .milliseconds(150))

        observerTask.cancel()

        #expect(yieldCount == 3)
    }

    @Test("Monitor supports multiple independent consumers") func multipleConsumers() async throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let monitor = SwiftDataChangeMonitor(modelContainer: container)

        var count1 = 0
        var count2 = 0

        let task1 = Task { @MainActor in
            for await _ in monitor.changes() {
                count1 += 1
                if count1 >= 1 { break }
            }
        }

        let task2 = Task { @MainActor in
            for await _ in monitor.changes() {
                count2 += 1
                if count2 >= 1 { break }
            }
        }

        await Task.yield()

        try storage.save(TestSwiftDataModel(name: "Test", value: 42))

        try await Task.sleep(for: .milliseconds(100))

        task1.cancel()
        task2.cancel()

        #expect(count1 == 1)
        #expect(count2 == 1)
    }

    @Test("Stream terminates when task is cancelled") func streamTerminatesOnCancellation() async throws {
        let container = try makeTestContainer()
        let monitor = SwiftDataChangeMonitor(modelContainer: container)

        var didFinish = false

        let observerTask = Task { @MainActor in
            for await _ in monitor.changes() {}
            didFinish = true
        }

        await Task.yield()
        observerTask.cancel()

        try await Task.sleep(for: .milliseconds(50))

        #expect(didFinish)
    }

    @Test("Monitor yields after delete") func yieldsAfterDelete() async throws {
        let container = try makeTestContainer()
        let storage = SwiftDataStorage<TestSwiftDataModel>(modelContainer: container)
        let monitor = SwiftDataChangeMonitor(modelContainer: container)

        // Pre-populate
        let model = TestSwiftDataModel(name: "ToDelete", value: 99)
        let modelID = model.id
        try storage.save(model)

        var yieldCount = 0

        let observerTask = Task { @MainActor in
            for await _ in monitor.changes() {
                yieldCount += 1
                if yieldCount >= 1 { break }
            }
        }

        await Task.yield()

        try storage.delete(id: modelID)

        try await Task.sleep(for: .milliseconds(100))

        observerTask.cancel()

        #expect(yieldCount == 1)
    }
}
