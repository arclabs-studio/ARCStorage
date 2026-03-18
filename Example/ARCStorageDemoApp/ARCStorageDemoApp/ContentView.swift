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
    private let preferencesViewModel: PreferencesViewModel
    private let authViewModel: AuthViewModel
    private let photoDemoViewModel: PhotoDemoViewModel

    // MARK: Initialization

    init(notesViewModel: NotesViewModel,
         persistentNotesViewModel: PersistentNotesViewModel,
         settingsViewModel: SettingsViewModel,
         preferencesViewModel: PreferencesViewModel,
         authViewModel: AuthViewModel,
         photoDemoViewModel: PhotoDemoViewModel) {
        self.notesViewModel = notesViewModel
        self.persistentNotesViewModel = persistentNotesViewModel
        self.settingsViewModel = settingsViewModel
        self.preferencesViewModel = preferencesViewModel
        self.authViewModel = authViewModel
        self.photoDemoViewModel = photoDemoViewModel
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

            Tab("Photos", systemImage: "photo.on.rectangle") {
                PhotoDemoView(viewModel: photoDemoViewModel)
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

            Tab("Preferences", systemImage: "slider.horizontal.3") {
                PreferencesView(viewModel: preferencesViewModel)
            }
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next no_force_try force_try
    let container = try! ModelContainer(for: PersistentNote.self, ARCPhoto.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)

    return ContentView(notesViewModel: NotesViewModel(repository: InMemoryRepository<Note>()),
                       persistentNotesViewModel: PersistentNotesViewModel(repository: repository),
                       settingsViewModel: SettingsViewModel(repository: UserDefaultsRepository<AppSettings>(keyPrefix: "Preview.Settings")),
                       preferencesViewModel: PreferencesViewModel(preferences: PreferenceStorage(keyPrefix: "Preview.Prefs")),
                       authViewModel: AuthViewModel(securityLevel: .whenUnlockedThisDeviceOnly),
                       photoDemoViewModel: PhotoDemoViewModel(modelContainer: container))
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next no_force_try force_try
    let container = try! ModelContainer(for: PersistentNote.self, ARCPhoto.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)

    return ContentView(notesViewModel: NotesViewModel(repository: InMemoryRepository<Note>()),
                       persistentNotesViewModel: PersistentNotesViewModel(repository: repository),
                       settingsViewModel: SettingsViewModel(repository: UserDefaultsRepository<AppSettings>(keyPrefix: "Preview.Settings")),
                       preferencesViewModel: PreferencesViewModel(preferences: PreferenceStorage(keyPrefix: "Preview.Prefs")),
                       authViewModel: AuthViewModel(securityLevel: .whenPasscodeSetThisDeviceOnly),
                       photoDemoViewModel: PhotoDemoViewModel(modelContainer: container))
        .preferredColorScheme(.dark)
}
