# Schema Migration Guide

Learn how to implement SwiftData schema migrations with ARCStorage.

## Overview

When your app's data model changes between versions, SwiftData needs to migrate existing data to the new schema. ARCStorage provides utilities and documentation to help implement migrations correctly.

## Migration Types

SwiftData supports two types of migrations:

### Lightweight Migrations (Automatic)

Handled automatically for simple changes:
- Adding new properties with default values
- Removing properties
- Renaming properties (with `@Attribute(originalName:)`)
- Adding or removing optional relationships

### Custom Migrations

Required for complex changes:
- Data transformations (e.g., splitting a full name into first/last)
- Changing property types
- Complex relationship restructuring
- Data validation or cleanup

## Implementing Migrations

### Step 1: Define Versioned Schemas

Create a versioned schema for each version of your model:

```swift
import SwiftData

// Version 1 - Original schema
enum RestaurantSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Restaurant.self]
    }

    @Model
    final class Restaurant {
        var id: UUID = UUID()
        var name: String = ""
        var address: String = ""
    }
}

// Version 2 - Updated schema
enum RestaurantSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Restaurant.self]
    }

    @Model
    final class Restaurant {
        @Attribute(.unique)
        var id: UUID = UUID()
        var name: String = ""

        // Renamed from 'address'
        @Attribute(originalName: "address")
        var streetAddress: String = ""

        // New properties
        var city: String = ""
        var rating: Double = 0.0
    }
}
```

### Step 2: Create Migration Plan

Define how to migrate between versions:

```swift
enum RestaurantMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RestaurantSchemaV1.self, RestaurantSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // Lightweight migration - property rename handled automatically
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: RestaurantSchemaV1.self,
        toVersion: RestaurantSchemaV2.self
    )
}
```

### Step 3: Configure Container

Use the migration plan when creating your container:

```swift
let config = SwiftDataConfiguration(
    schema: Schema(versionedSchema: RestaurantSchemaV2.self),
    isCloudKitEnabled: false
)
let container = try config.makeContainer(
    migrationPlan: RestaurantMigrationPlan.self
)
```

Or use the convenience function:

```swift
let container = try makeVersionedContainer(
    schema: RestaurantSchemaV2.self,
    migrationPlan: RestaurantMigrationPlan.self,
    isCloudKitEnabled: false
)
```

## Custom Migration Example

For complex data transformations, use custom migration stages:

```swift
enum NoteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NoteSchemaV1.self, NoteSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: NoteSchemaV1.self,
        toVersion: NoteSchemaV2.self,
        willMigrate: { context in
            // Called BEFORE schema changes
            // Use to backup or validate data
            let notes = try context.fetch(FetchDescriptor<NoteSchemaV1.Note>())
            print("Migrating \(notes.count) notes")
        },
        didMigrate: { context in
            // Called AFTER schema changes
            // Use to transform data
            let notes = try context.fetch(FetchDescriptor<NoteSchemaV2.Note>())
            for note in notes {
                // Set default values for new properties
                if note.category.isEmpty {
                    note.category = "Uncategorized"
                }

                // Transform existing data
                if note.title.isEmpty {
                    note.title = "Untitled Note"
                }
            }
            try context.save()
        }
    )
}
```

## Testing Migrations

Always test migrations with sample data:

```swift
import Testing
@testable import YourApp

@Test("Migration from V1 to V2 preserves data")
func testMigration() throws {
    // Create V1 data
    let container = try ModelContainer(
        for: Schema(versionedSchema: NoteSchemaV1.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let note = NoteSchemaV1.Note()
    note.id = UUID()
    note.title = "Test Note"
    context.insert(note)
    try context.save()

    // Perform migration
    let migratedContainer = try makeVersionedContainer(
        schema: NoteSchemaV2.self,
        migrationPlan: NoteMigrationPlan.self
    )

    // Verify data
    let migratedNotes = try migratedContainer.mainContext.fetch(
        FetchDescriptor<NoteSchemaV2.Note>()
    )
    #expect(migratedNotes.count == 1)
    #expect(migratedNotes.first?.title == "Test Note")
}
```

## CloudKit Considerations

When using CloudKit with migrations:

1. **Migrations only affect local data** - CloudKit schema is separate
2. **CloudKit schema changes** must be done in CloudKit Dashboard
3. **New properties must be optional or have defaults** for CloudKit compatibility
4. **Test with production containers** before release

## Best Practices

1. **Keep versioned schemas immutable** - Never modify existing schema versions
2. **Use willMigrate for backup** - Save critical data before schema changes
3. **Use didMigrate for transformation** - Transform data after schema updates
4. **Test migrations thoroughly** - Create unit tests with realistic sample data
5. **Plan for rollback** - Consider how to handle migration failures
6. **Document schema versions** - Keep a changelog of schema changes

## Troubleshooting

### Migration Fails Silently

- Check that all schema versions are included in `schemas` array
- Verify `versionIdentifier` is unique for each version
- Ensure migration stages cover all version transitions

### Data Loss After Migration

- Verify `willMigrate` isn't deleting data
- Check that property renames use `@Attribute(originalName:)`
- Ensure new required properties have default values

### Performance Issues

- Batch large data transformations
- Consider async migration for large datasets
- Monitor memory usage during migration

## Topics

### Configuration
- ``SwiftDataConfiguration``
- ``makeVersionedContainer(schema:migrationPlan:isCloudKitEnabled:)``

### Migration Types
- ``SwiftDataMigrationStage``
