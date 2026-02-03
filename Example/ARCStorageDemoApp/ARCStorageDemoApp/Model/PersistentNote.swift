//
//  PersistentNote.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 21/01/2026.
//

import ARCStorage
import Foundation
import SwiftData

/// A SwiftData-backed note model demonstrating Swift 6 compatibility.
///
/// This model conforms to `SwiftDataEntity` which does NOT require
/// `Sendable` or `Codable` - making it fully compatible with Swift 6
/// strict concurrency mode.
///
/// ## Best Practices Demonstrated
///
/// - Uses `@Attribute(.unique)` on `id` for database indexing and O(1) lookups
/// - All properties have default values for CloudKit compatibility
/// - Follows SwiftData naming conventions
@Model
final class PersistentNote: SwiftDataEntity {
    // MARK: Properties

    /// Unique identifier with database index for fast lookups.
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var colorName: String

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        colorName: String = "yellow"
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.colorName = colorName
    }
}

// MARK: - Color Helper

extension PersistentNote {
    var noteColor: NoteColor {
        get { NoteColor(rawValue: colorName) ?? .yellow }
        set { colorName = newValue.rawValue }
    }
}

// MARK: - Sample Data

extension PersistentNote {
    static func createSamples() -> [PersistentNote] {
        [
            PersistentNote(
                title: "SwiftData + ARCStorage",
                content: "This note is persisted using SwiftData with Swift 6 strict concurrency.",
                isPinned: true,
                colorName: "yellow"
            ),
            PersistentNote(
                title: "No Sendable Required",
                content: "Unlike InMemory storage, SwiftData models don't need Sendable conformance.",
                colorName: "blue"
            ),
            PersistentNote(
                title: "MainActor Isolation",
                content: "SwiftDataStorage and SwiftDataRepository are @MainActor isolated for safety.",
                colorName: "green"
            ),
        ]
    }
}
