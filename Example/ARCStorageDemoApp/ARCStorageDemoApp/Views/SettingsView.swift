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
    fileprivate var displaySection: some View {
        Section("Display") {
            Toggle("Show Pinned First", isOn: Binding(
                get: { viewModel.settings.showPinnedFirst },
                set: { value in
                    Task { await viewModel.setShowPinnedFirst(value) }
                }
            ))
        }
    }

    fileprivate var notesSection: some View {
        Section("Notes") {
            Picker("Default Color", selection: Binding(
                get: { viewModel.settings.defaultNoteColor },
                set: { color in
                    Task { await viewModel.setDefaultNoteColor(color) }
                }
            )) {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Text(color.displayName).tag(color)
                }
            }

            Stepper(
                "Notes per page: \(viewModel.settings.notesPerPage)",
                value: Binding(
                    get: { viewModel.settings.notesPerPage },
                    set: { count in
                        Task { await viewModel.setNotesPerPage(count) }
                    }
                ),
                in: 5 ... 100,
                step: 5
            )
        }
    }

    fileprivate var cacheSection: some View {
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

    fileprivate var infoSection: some View {
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
    SettingsView(
        viewModel: SettingsViewModel(
            repository: UserDefaultsRepository<AppSettings>(
                keyPrefix: "Preview.Settings"
            )
        )
    )
}
