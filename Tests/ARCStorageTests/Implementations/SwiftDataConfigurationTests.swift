import Foundation
import SwiftData
import Testing
@testable import ARCStorage

@Suite("SwiftDataConfiguration Tests")
@MainActor
struct SwiftDataConfigurationTests {
    @Model
    final class ConfigTestModel: SwiftDataEntity {
        var id = UUID()
        var name: String = ""

        init(id: UUID = UUID(), name: String = "") {
            self.id = id
            self.name = name
        }
    }

    private func makeSUT(cloudKit: CloudKitOption = .disabled) -> SwiftDataConfiguration {
        SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]), cloudKit: cloudKit)
    }

    @Test("Default cloudKit is disabled") func defaultCloudKit_isDisabled() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]))

        // Then
        #expect(sut.cloudKit == .disabled)
    }

    @Test("Disabled config creates local-only container") func disabledConfig_createsLocalOnlyContainer() throws {
        // Given
        let sut = makeSUT(cloudKit: .disabled)

        // When
        let container = try sut.makeContainer()

        // Then
        #expect(container.schema.entities.isEmpty == false)
    }

    @Test("cloudKit property round-trips correctly") func cloudKitProperty_roundTrips() {
        // Given
        let identifier = "iCloud.com.arclabs.test"
        let option = CloudKitOption.enabled(containerIdentifier: identifier)

        // When
        let sut = makeSUT(cloudKit: option)

        // Then
        #expect(sut.cloudKit == option)
    }

    @Test("allowsSave defaults to true") func allowsSave_defaultsToTrue() {
        // Given
        let sut = makeSUT()

        // Then
        #expect(sut.allowsSave == true)
    }

    @Test("allowsSave can be set to false") func allowsSave_canBeSetToFalse() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         cloudKit: .disabled,
                                         allowsSave: false)

        // Then
        #expect(sut.allowsSave == false)
    }

    @Test("makeContainerWithFallback with disabled creates container")
    func makeContainerWithFallback_disabled_createsContainer() async throws {
        // Given
        let sut = makeSUT(cloudKit: .disabled)

        // When
        let container = try await sut.makeContainerWithFallback()

        // Then
        #expect(container.schema.entities.isEmpty == false)
    }

    // Note: makeContainerWithFallback with CloudKit enabled calls CKContainer.accountStatus()
    // which hangs in package test environments without CloudKit entitlements.
    // Full integration tests for CloudKit fallback belong in the demo app.
}
