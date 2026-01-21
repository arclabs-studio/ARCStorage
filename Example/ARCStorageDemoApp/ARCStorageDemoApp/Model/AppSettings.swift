//
//  AppSettings.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import Foundation

/// App settings model persisted via UserDefaultsRepository.
struct AppSettings: Codable, Sendable, Identifiable {
    // MARK: Properties

    let id: String
    var showPinnedFirst: Bool
    var defaultNoteColor: NoteColor
    var notesPerPage: Int
    var lastSyncDate: Date?

    // MARK: Initialization

    init(
        id: String = "main",
        showPinnedFirst: Bool = true,
        defaultNoteColor: NoteColor = .yellow,
        notesPerPage: Int = 20,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.showPinnedFirst = showPinnedFirst
        self.defaultNoteColor = defaultNoteColor
        self.notesPerPage = notesPerPage
        self.lastSyncDate = lastSyncDate
    }
}

// MARK: - Default Settings

extension AppSettings {
    static let `default` = AppSettings()
}
