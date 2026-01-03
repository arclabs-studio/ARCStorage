//
//  SettingsViewModel.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import Foundation

/// ViewModel for managing app settings using UserDefaultsRepository.
///
/// Demonstrates persistence with UserDefaults backend.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: Public Properties

    private(set) var settings: AppSettings = .default
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastSaveDate: Date?

    // MARK: Private Properties

    private let repository: UserDefaultsRepository<AppSettings>

    // MARK: Initialization

    init(repository: UserDefaultsRepository<AppSettings>) {
        self.repository = repository
    }

    // MARK: Public Functions

    /// Loads settings from the repository.
    func loadSettings() async {
        isLoading = true
        errorMessage = nil

        do {
            if let saved = try await repository.fetch(id: "main") {
                settings = saved
            } else {
                settings = .default
                try await repository.save(settings)
            }
        } catch {
            errorMessage = error.localizedDescription
            settings = .default
        }

        isLoading = false
    }

    /// Saves the current settings.
    func saveSettings() async {
        do {
            try await repository.save(settings)
            lastSaveDate = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates the show pinned first setting.
    func setShowPinnedFirst(_ value: Bool) async {
        settings.showPinnedFirst = value
        await saveSettings()
    }

    /// Updates the default note color.
    func setDefaultNoteColor(_ color: NoteColor) async {
        settings.defaultNoteColor = color
        await saveSettings()
    }

    /// Updates the notes per page setting.
    func setNotesPerPage(_ count: Int) async {
        settings.notesPerPage = max(5, min(100, count))
        await saveSettings()
    }

    /// Resets settings to defaults.
    func resetToDefaults() async {
        settings = .default
        await saveSettings()
    }

    /// Clears cache and reloads settings.
    func refreshSettings() async {
        await repository.invalidateCache()
        await loadSettings()
    }
}
