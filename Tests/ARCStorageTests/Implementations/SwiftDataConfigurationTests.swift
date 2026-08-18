import Foundation
import SwiftData
import Testing
@testable import ARCStorage

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

    // MARK: - storeName

    @Test("storeName omitted uses default name") func storeName_omitted_usesDefaultName() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]))

        // Then
        #expect(sut.modelConfiguration.name == "default")
    }

    @Test("storeName sets backing file name") func storeName_setsBackingFileName() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         storeName: "arc-photos")

        // Then
        #expect(sut.modelConfiguration.name == "arc-photos")
    }

    @Test("Two configs with different storeNames have distinct names") func twoConfigs_differentStoreNames_areDistinct() {
        // Given
        let primary = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]))
        let secondary = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                               storeName: "secondary")

        // Then
        #expect(primary.modelConfiguration.name != secondary.modelConfiguration.name)
    }

    @Test("storeName config creates container successfully") func storeName_createsContainerSuccessfully() throws {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         storeName: "test-store")

        // When
        let container = try sut.makeContainer()

        // Then
        #expect(container.schema.entities.isEmpty == false)
    }

    @Test("storeName is exposed on the configuration") func storeName_isExposed() {
        // Given
        let named = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]), storeName: "arc-photos")
        let unnamed = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]))

        // Then
        #expect(named.storeName == "arc-photos")
        #expect(unnamed.storeName == nil)
    }

    // MARK: - Local-only fallback configuration

    @Test("Local-only fallback keeps the named store URL") func localOnlyConfiguration_withStoreName_preservesURL() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         storeName: "arc-photos",
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"))

        // When
        let localConfig = sut.localOnlyConfiguration()

        // Then
        #expect(localConfig.url == sut.modelConfiguration.url)
        #expect(localConfig.name == "arc-photos")
    }

    @Test("Local-only fallback keeps the default store URL")
    func localOnlyConfiguration_withoutStoreName_preservesDefaultURL() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"))

        // When
        let localConfig = sut.localOnlyConfiguration()

        // Then
        #expect(localConfig.url == sut.modelConfiguration.url)
    }

    @Test("Local-only fallback disables CloudKit") func localOnlyConfiguration_disablesCloudKit() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         storeName: "arc-photos",
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"))

        // When
        let localConfig = sut.localOnlyConfiguration()

        // Then
        #expect(localConfig.cloudKitContainerIdentifier == nil)
        #expect(sut.modelConfiguration.cloudKitContainerIdentifier == "iCloud.com.arclabs.test")
    }

    @Test("Local-only fallback keeps allowsSave") func localOnlyConfiguration_keepsAllowsSave() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]),
                                         storeName: "arc-photos",
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"),
                                         allowsSave: false)

        // Then
        #expect(sut.localOnlyConfiguration().allowsSave == false)
    }

    // MARK: - makeContainerReportingMode

    @Test("makeContainerReportingMode with disabled reports localOnly")
    func makeContainerReportingMode_disabled_reportsLocalOnly() async throws {
        // Given
        let sut = makeSUT(cloudKit: .disabled)

        // When
        let result = try await sut.makeContainerReportingMode()

        // Then
        #expect(result.mode == .localOnly)
        #expect(result.container.schema.entities.isEmpty == false)
    }

    @Test("ContainerResult round-trips container and mode") func containerResult_roundTrips() throws {
        // Given
        let sut = makeSUT(cloudKit: .disabled)
        let container = try sut.makeContainer()

        // When
        let result = ContainerResult(container: container, mode: .localFallback(reason: .noAccount))

        // Then
        #expect(result.container === container)
        #expect(result.mode == .localFallback(reason: .noAccount))
    }

    // MARK: - migrationPlan

    enum ConfigTestSchemaV1: VersionedSchema {
        static var versionIdentifier: Schema.Version {
            Schema.Version(1, 0, 0)
        }

        static var models: [any PersistentModel.Type] {
            [ConfigTestModel.self]
        }
    }

    enum ConfigTestMigrationPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] {
            [ConfigTestSchemaV1.self]
        }

        static var stages: [MigrationStage] {
            []
        }
    }

    @Test("migrationPlan defaults to nil") func migrationPlan_defaultsToNil() {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema([ConfigTestModel.self]))

        // Then
        #expect(sut.migrationPlan == nil)
    }

    @Test("Config with a migration plan builds a container via makeContainer")
    func migrationPlan_buildsContainerViaMakeContainer() throws {
        // Given
        let sut = SwiftDataConfiguration(schema: Schema(versionedSchema: ConfigTestSchemaV1.self),
                                         migrationPlan: ConfigTestMigrationPlan.self)

        // When
        let container = try sut.makeContainer()

        // Then
        #expect(sut.migrationPlan != nil)
        #expect(container.schema.entities.isEmpty == false)
    }

    @Test("makeContainerWithFallback with disabled + migration plan builds a container")
    func makeContainerWithFallback_disabledWithMigrationPlan_buildsContainer() async throws {
        // Given — exercises the delegation path (fallback → makeContainer with a plan)
        let sut = SwiftDataConfiguration(schema: Schema(versionedSchema: ConfigTestSchemaV1.self),
                                         cloudKit: .disabled,
                                         migrationPlan: ConfigTestMigrationPlan.self)

        // When
        let container = try await sut.makeContainerWithFallback()

        // Then
        #expect(container.schema.entities.isEmpty == false)
    }

    // Note: the CloudKit-enabled + migrationPlan branch of makeLocalOnlyContainer() can't be
    // exercised in-package for the same reason as the CloudKit fallback above —
    // CKContainer.accountStatus() hangs without CloudKit entitlements. Covered in the demo app.
}
