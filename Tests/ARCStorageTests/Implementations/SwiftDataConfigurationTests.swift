import Foundation
import SwiftData
import Testing
@testable import ARCStorage

@Suite("SwiftDataConfiguration Tests")
@MainActor struct SwiftDataConfigurationTests {
    @Model final class ConfigTestModel: SwiftDataEntity {
        @Attribute(.unique) var id: UUID
        var name: String

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

    @Test("Deprecated isCloudKitEnabled returns false when disabled")
    @available(*, deprecated) func deprecatedIsCloudKitEnabled_returnsFalse_whenDisabled() {
        // Given
        let sut = makeSUT(cloudKit: .disabled)

        // Then
        #expect(sut.isCloudKitEnabled == false)
    }

    @Test("Deprecated isCloudKitEnabled returns true when enabled")
    @available(*, deprecated) func deprecatedIsCloudKitEnabled_returnsTrue_whenEnabled() {
        // Given
        let sut = makeSUT(cloudKit: .enabled(containerIdentifier: "iCloud.com.test"))

        // Then
        #expect(sut.isCloudKitEnabled == true)
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
}
