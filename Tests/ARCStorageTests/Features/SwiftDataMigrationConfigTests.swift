import Foundation
import SwiftData
import Testing
@testable import ARCStorage

@Model
final class MigrationTestModel: SwiftDataEntity {
    var id = UUID()
    var name: String = ""

    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
}

enum MigrationTestSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [MigrationTestModel.self]
    }
}

enum MigrationTestPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MigrationTestSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

@MainActor
struct SwiftDataMigrationConfigTests {
    private func makeSchema() -> Schema {
        Schema(versionedSchema: MigrationTestSchemaV1.self)
    }

    // MARK: - storeName forwarding

    @Test("Migration init forwards storeName") func migrationInit_forwardsStoreName() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         migrationPlan: MigrationTestPlan.self,
                                         storeName: "arc-migrated")

        // Then
        #expect(sut.storeName == "arc-migrated")
        #expect(sut.modelConfiguration.name == "arc-migrated")
    }

    @Test("Migration init without storeName uses default name") func migrationInit_omittedStoreName_usesDefault() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         migrationPlan: MigrationTestPlan.self)

        // Then
        #expect(sut.storeName == nil)
        #expect(sut.modelConfiguration.name == "default")
    }

    @Test("Migration init keeps cloudKit and allowsSave") func migrationInit_keepsOtherParameters() {
        // Given
        let option = CloudKitOption.enabled(containerIdentifier: "iCloud.com.arclabs.test")
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         migrationPlan: MigrationTestPlan.self,
                                         storeName: "arc-migrated",
                                         cloudKit: option,
                                         allowsSave: false)

        // Then
        #expect(sut.cloudKit == option)
        #expect(sut.allowsSave == false)
    }

    @Test("Migration config local-only fallback preserves store URL")
    func migrationConfig_localOnlyFallback_preservesURL() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         migrationPlan: MigrationTestPlan.self,
                                         storeName: "arc-migrated",
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"))

        // When
        let localConfig = sut.localOnlyConfiguration()

        // Then
        #expect(localConfig.url == sut.modelConfiguration.url)
        #expect(localConfig.name == "arc-migrated")
    }

    // MARK: - makeVersionedContainer

    @Test("Versioned container with storeName creates container")
    func makeVersionedContainer_withStoreName_createsContainer() throws {
        // When
        let container = try makeVersionedContainer(schema: MigrationTestSchemaV1.self,
                                                   migrationPlan: MigrationTestPlan.self,
                                                   storeName: "arc-versioned")

        // Then
        #expect(container.schema.entities.isEmpty == false)
        #expect(container.configurations.contains { $0.name == "arc-versioned" })
    }

    @Test("Versioned container without storeName uses default name")
    func makeVersionedContainer_omittedStoreName_usesDefault() throws {
        // When
        let container = try makeVersionedContainer(schema: MigrationTestSchemaV1.self,
                                                   migrationPlan: MigrationTestPlan.self)

        // Then
        #expect(container.configurations.contains { $0.name == "default" })
    }
}
