//
//  ContentView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftUI

struct ContentView: View {
    // MARK: Private Properties

    private let notesViewModel: NotesViewModel
    private let settingsViewModel: SettingsViewModel
    private let authViewModel: AuthViewModel

    // MARK: Initialization

    init(
        notesViewModel: NotesViewModel,
        settingsViewModel: SettingsViewModel,
        authViewModel: AuthViewModel
    ) {
        self.notesViewModel = notesViewModel
        self.settingsViewModel = settingsViewModel
        self.authViewModel = authViewModel
    }

    // MARK: Body

    var body: some View {
        TabView {
            Tab("Notes", systemImage: "note.text") {
                NoteListView(viewModel: notesViewModel)
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
    ContentView(
        notesViewModel: NotesViewModel(
            repository: InMemoryRepository<Note>()
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
    ContentView(
        notesViewModel: NotesViewModel(
            repository: InMemoryRepository<Note>()
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
