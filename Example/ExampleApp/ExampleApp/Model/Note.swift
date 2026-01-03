//
//  Note.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import Foundation

/// A simple note model for demonstrating ARCStorage capabilities.
struct Note: Codable, Sendable, Identifiable, Hashable {
    // MARK: Properties

    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var color: NoteColor

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        color: NoteColor = .yellow
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.color = color
    }
}

// MARK: - NoteColor

enum NoteColor: String, Codable, Sendable, CaseIterable {
    case yellow
    case blue
    case green
    case pink
    case purple

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Sample Data

extension Note {
    static let samples: [Note] = [
        Note(
            title: "Welcome to ARCStorage",
            content: "This is a demo app showing the capabilities of ARCStorage package.",
            isPinned: true,
            color: .yellow
        ),
        Note(
            title: "Repository Pattern",
            content: "ARCStorage uses the Repository pattern to abstract persistence.",
            color: .blue
        ),
        Note(
            title: "Multiple Backends",
            content: "Supports InMemory, UserDefaults, Keychain, and SwiftData storage.",
            color: .green
        )
    ]
}
