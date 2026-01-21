//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftData
import SwiftUI

@main
struct ExampleApp: App {
    // MARK: Private Properties

    private let notesViewModel: NotesViewModel
    private let persistentNotesViewModel: PersistentNotesViewModel
    private let settingsViewModel: SettingsViewModel
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

        // Settings: UserDefaults storage (persistent)
        let settingsRepository = UserDefaultsRepository<AppSettings>(
            keyPrefix: "ExampleApp.Settings"
        )
        settingsViewModel = SettingsViewModel(repository: settingsRepository)

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
                authViewModel: authViewModel
            )
        }
    }
}
