//
//  SettingsView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftUI

struct SettingsView: View {
    // MARK: Private Properties

    @Bindable private var viewModel: SettingsViewModel
    @State private var showResetConfirmation = false

    // MARK: Initialization

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                notesSection
                cacheSection
                infoSection
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadSettings()
            }
            .refreshable {
                await viewModel.refreshSettings()
            }
            .alert("Reset Settings", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.resetToDefaults()
                    }
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
}

// MARK: - Sections

extension SettingsView {
    private var displaySection: some View {
        Section("Display") {
            Toggle("Show Pinned First", isOn: $viewModel.showPinnedFirst)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            Picker("Default Color", selection: $viewModel.defaultNoteColor) {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Text(color.displayName).tag(color)
                }
            }

            Stepper("Notes per page: \(viewModel.notesPerPage)",
                    value: $viewModel.notesPerPage,
                    in: 5 ... 100,
                    step: 5)
        }
    }

    private var cacheSection: some View {
        Section {
            Button("Refresh from Storage") {
                Task {
                    await viewModel.refreshSettings()
                }
            }

            Button("Reset to Defaults", role: .destructive) {
                showResetConfirmation = true
            }
        } header: {
            Text("Cache")
        } footer: {
            Text("Settings are persisted using UserDefaultsRepository with LRU caching.")
        }
    }

    private var infoSection: some View {
        Section("Info") {
            if let lastSave = viewModel.lastSaveDate {
                LabeledContent("Last Saved") {
                    Text(lastSave, style: .relative)
                }
            }

            LabeledContent("Storage Backend") {
                Text("UserDefaults")
            }

            LabeledContent("Cache Policy") {
                Text("Default (5 min TTL)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let repository = UserDefaultsRepository<AppSettings>(keyPrefix: "Preview.Settings")
    SettingsView(viewModel: SettingsViewModel(repository: repository))
}
