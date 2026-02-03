//
//  ContentView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftData
import SwiftUI

struct ContentView: View {
    // MARK: Private Properties

    private let notesViewModel: NotesViewModel
    private let persistentNotesViewModel: PersistentNotesViewModel
    private let settingsViewModel: SettingsViewModel
    private let authViewModel: AuthViewModel

    // MARK: Initialization

    init(
        notesViewModel: NotesViewModel,
        persistentNotesViewModel: PersistentNotesViewModel,
        settingsViewModel: SettingsViewModel,
        authViewModel: AuthViewModel
    ) {
        self.notesViewModel = notesViewModel
        self.persistentNotesViewModel = persistentNotesViewModel
        self.settingsViewModel = settingsViewModel
        self.authViewModel = authViewModel
    }

    // MARK: Body

    var body: some View {
        TabView {
            Tab("In-Memory", systemImage: "memorychip") {
                NoteListView(viewModel: notesViewModel)
            }

            Tab("SwiftData", systemImage: "externaldrive.fill") {
                PersistentNoteListView(viewModel: persistentNotesViewModel)
            }

            Tab("CloudKit", systemImage: "icloud") {
                CloudKitSyncView()
            }

            Tab("Secure", systemImage: "lock.shield") {
                AuthView(viewModel: authViewModel)
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView(viewModel: settingsViewModel)
            }
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersistentNote.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)

    return ContentView(
        notesViewModel: NotesViewModel(
            repository: InMemoryRepository<Note>()
        ),
        persistentNotesViewModel: PersistentNotesViewModel(
            repository: repository
        ),
        settingsViewModel: SettingsViewModel(
            repository: UserDefaultsRepository<AppSettings>(
                keyPrefix: "Preview.Settings"
            )
        ),
        authViewModel: AuthViewModel(
            securityLevel: .whenUnlockedThisDeviceOnly
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersistentNote.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)

    return ContentView(
        notesViewModel: NotesViewModel(
            repository: InMemoryRepository<Note>()
        ),
        persistentNotesViewModel: PersistentNotesViewModel(
            repository: repository
        ),
        settingsViewModel: SettingsViewModel(
            repository: UserDefaultsRepository<AppSettings>(
                keyPrefix: "Preview.Settings"
            )
        ),
        authViewModel: AuthViewModel(
            securityLevel: .whenPasscodeSetThisDeviceOnly
        )
    )
    .preferredColorScheme(.dark)
}
