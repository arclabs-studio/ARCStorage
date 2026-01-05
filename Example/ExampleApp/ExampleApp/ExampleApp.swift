//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftUI

@main
struct ExampleApp: App {
    // MARK: Private Properties

    private let notesViewModel: NotesViewModel
    private let settingsViewModel: SettingsViewModel
    private let authViewModel: AuthViewModel

    // MARK: Initialization

    init() {
        // Notes: In-memory storage (volatile)
        let notesRepository = InMemoryRepository<Note>()
        notesViewModel = NotesViewModel(repository: notesRepository)

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
                settingsViewModel: settingsViewModel,
                authViewModel: authViewModel
            )
        }
    }
}
