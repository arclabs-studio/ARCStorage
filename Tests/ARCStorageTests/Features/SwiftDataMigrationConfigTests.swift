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

    // MARK: - storeName with a migration plan

    @Test("Migration plan config keeps storeName") func migrationPlanConfig_keepsStoreName() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         storeName: "arc-migrated",
                                         migrationPlan: MigrationTestPlan.self)

        // Then
        #expect(sut.storeName == "arc-migrated")
        #expect(sut.modelConfiguration.name == "arc-migrated")
        #expect(sut.migrationPlan != nil)
    }

    @Test("Migration plan config without storeName uses default name")
    func migrationPlanConfig_omittedStoreName_usesDefault() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         migrationPlan: MigrationTestPlan.self)

        // Then
        #expect(sut.storeName == nil)
        #expect(sut.modelConfiguration.name == "default")
    }

    @Test("Migration plan config local-only fallback preserves store URL")
    func migrationPlanConfig_localOnlyFallback_preservesURL() {
        // Given
        let sut = SwiftDataConfiguration(schema: makeSchema(),
                                         storeName: "arc-migrated",
                                         cloudKit: .enabled(containerIdentifier: "iCloud.com.arclabs.test"),
                                         migrationPlan: MigrationTestPlan.self)

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
