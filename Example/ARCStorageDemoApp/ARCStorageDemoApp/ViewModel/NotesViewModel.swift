//
//  NotesViewModel.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import Foundation

/// ViewModel for managing notes using InMemoryRepository.
///
/// Demonstrates CRUD operations with ARCStorage's Repository protocol.
@MainActor
@Observable
final class NotesViewModel {
    // MARK: Public Properties

    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: Private Properties

    private let repository: InMemoryRepository<Note>

    // MARK: Initialization

    init(repository: InMemoryRepository<Note>) {
        self.repository = repository
    }

    // MARK: Public Functions

    /// Loads all notes from the repository.
    func loadNotes() async {
        isLoading = true
        errorMessage = nil

        do {
            notes = try await repository.fetchAll()
            sortNotes()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Adds a new note.
    func addNote(_ note: Note) async {
        do {
            try await repository.save(note)
            await loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates an existing note.
    func updateNote(_ note: Note) async {
        var updated = note
        updated.updatedAt = Date()

        do {
            try await repository.save(updated)
            await loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a note by ID.
    func deleteNote(id: UUID) async {
        do {
            try await repository.delete(id: id)
            await loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggles the pinned state of a note.
    func togglePin(_ note: Note) async {
        var updated = note
        updated.isPinned.toggle()
        updated.updatedAt = Date()

        await updateNote(updated)
    }

    /// Loads sample data for demonstration.
    func loadSampleData() async {
        for note in Note.samples {
            try? await repository.save(note)
        }
        await loadNotes()
    }

    /// Clears all notes.
    func clearAllNotes() async {
        for note in notes {
            try? await repository.delete(id: note.id)
        }
        await loadNotes()
    }

    /// Invalidates the cache and reloads notes.
    func refreshNotes() async {
        await repository.invalidateCache()
        await loadNotes()
    }
}

// MARK: - Private Functions

extension NotesViewModel {
    private func sortNotes() {
        notes.sort { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned
            }
            return first.updatedAt > second.updatedAt
        }
    }
}
