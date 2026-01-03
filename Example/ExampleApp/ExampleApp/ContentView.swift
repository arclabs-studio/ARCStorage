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

    // MARK: Initialization

    init(notesViewModel: NotesViewModel, settingsViewModel: SettingsViewModel) {
        self.notesViewModel = notesViewModel
        self.settingsViewModel = settingsViewModel
    }

    // MARK: Body

    var body: some View {
        TabView {
            Tab("Notes", systemImage: "note.text") {
                NoteListView(viewModel: notesViewModel)
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
        )
    )
    .preferredColorScheme(.dark)
}
