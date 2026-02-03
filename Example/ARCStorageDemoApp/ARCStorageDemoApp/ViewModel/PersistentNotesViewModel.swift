//
//  PersistentNotesViewModel.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 21/01/2026.
//

import ARCStorage
import Foundation
import SwiftData

/// ViewModel for managing persistent notes using SwiftDataRepository.
///
/// Demonstrates CRUD operations with ARCStorage's SwiftData integration,
/// fully compatible with Swift 6 strict concurrency.
///
/// Note: All operations are synchronous because `SwiftDataRepository`
/// is `@MainActor` isolated. No `async/await` needed!
@MainActor
@Observable
final class PersistentNotesViewModel {
    // MARK: Public Properties

    private(set) var notes: [PersistentNote] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: Private Properties

    private let repository: SwiftDataRepository<PersistentNote>

    // MARK: Initialization

    init(repository: SwiftDataRepository<PersistentNote>) {
        self.repository = repository
    }

    // MARK: Public Functions

    /// Loads all notes from the repository.
    func loadNotes() {
        isLoading = true
        errorMessage = nil

        do {
            notes = try repository.fetchAll()
            sortNotes()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Adds a new note.
    func addNote(_ note: PersistentNote) {
        do {
            try repository.save(note)
            loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates an existing note.
    func updateNote(_ note: PersistentNote) {
        note.updatedAt = Date()

        do {
            try repository.save(note)
            loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a note by ID.
    func deleteNote(id: UUID) {
        do {
            try repository.delete(id: id)
            loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggles the pinned state of a note.
    func togglePin(_ note: PersistentNote) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        updateNote(note)
    }

    /// Loads sample data for demonstration.
    func loadSampleData() {
        for note in PersistentNote.createSamples() {
            try? repository.save(note)
        }
        loadNotes()
    }

    /// Clears all notes.
    func clearAllNotes() {
        do {
            try repository.deleteAll()
            loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Private Functions

extension PersistentNotesViewModel {
    private func sortNotes() {
        notes.sort { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned
            }
            return first.updatedAt > second.updatedAt
        }
    }
}
