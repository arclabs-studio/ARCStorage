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

    // MARK: Initialization

    init() {
        let notesRepository = InMemoryRepository<Note>()
        notesViewModel = NotesViewModel(repository: notesRepository)

        let settingsRepository = UserDefaultsRepository<AppSettings>(
            keyPrefix: "ExampleApp.Settings"
        )
        settingsViewModel = SettingsViewModel(repository: settingsRepository)
    }

    // MARK: Body

    var body: some Scene {
        WindowGroup {
            ContentView(
                notesViewModel: notesViewModel,
                settingsViewModel: settingsViewModel
            )
        }
    }
}
