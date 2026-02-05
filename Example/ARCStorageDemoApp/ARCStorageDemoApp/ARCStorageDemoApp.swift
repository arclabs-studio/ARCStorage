//
//  ARCStorageDemoApp.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftData
import SwiftUI

@main
struct ARCStorageDemoApp: App {
    // MARK: Private Properties

    private let notesViewModel: NotesViewModel
    private let persistentNotesViewModel: PersistentNotesViewModel
    private let settingsViewModel: SettingsViewModel
    private let preferencesViewModel: PreferencesViewModel
    private let authViewModel: AuthViewModel

    // MARK: Initialization

    init() {
        // Notes: In-memory storage (volatile)
        let notesRepository = InMemoryRepository<Note>()
        notesViewModel = NotesViewModel(repository: notesRepository)

        // Persistent Notes: SwiftData storage (persistent, Swift 6 compatible)
        let modelContainer = try! ModelContainer(for: PersistentNote.self)
        let persistentStorage = SwiftDataStorage<PersistentNote>(modelContainer: modelContainer)
        let persistentRepository = SwiftDataRepository(storage: persistentStorage)
        persistentNotesViewModel = PersistentNotesViewModel(repository: persistentRepository)

        // Settings: UserDefaults storage (persistent, async, entity-based)
        let settingsRepository = UserDefaultsRepository<AppSettings>(
            keyPrefix: "ARCStorageDemoApp.Settings"
        )
        settingsViewModel = SettingsViewModel(repository: settingsRepository)

        // Preferences: PreferenceStorage (synchronous, key-value based)
        // Note: This is created synchronously - no async required!
        preferencesViewModel = PreferencesViewModel(
            preferences: PreferenceStorage(keyPrefix: "ARCStorageDemoApp.Prefs")
        )

        // Auth: Keychain storage (secure, with high security level)
        authViewModel = AuthViewModel(
            securityLevel: .whenUnlockedThisDeviceOnly,
            service: "com.arclabs.exampleapp.auth"
        )
    }

    // MARK: Body

    var body: some Scene {
        WindowGroup {
            ContentView(
                notesViewModel: notesViewModel,
                persistentNotesViewModel: persistentNotesViewModel,
                settingsViewModel: settingsViewModel,
                preferencesViewModel: preferencesViewModel,
                authViewModel: authViewModel
            )
            .preferredColorScheme(preferencesViewModel.isDarkModeEnabled ? .dark : .light)
        }
    }
}
