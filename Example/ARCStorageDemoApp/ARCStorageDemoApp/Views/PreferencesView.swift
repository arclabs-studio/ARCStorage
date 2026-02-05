//
//  PreferencesView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 05/02/2026.
//

import ARCStorage
import SwiftUI

/// View demonstrating PreferenceStorage for simple key-value preferences.
///
/// This view shows the synchronous PreferenceStorage API in contrast to
/// SettingsView which uses the async UserDefaultsRepository.
struct PreferencesView: View {
    // MARK: Private Properties

    @Bindable private var viewModel: PreferencesViewModel
    @State private var showResetConfirmation = false

    // MARK: Initialization

    init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                notificationsSection
                displaySection
                statsSection
                actionsSection
                infoSection
            }
            .navigationTitle("Preferences")
            .alert("Reset Preferences", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("This will reset all preferences to their default values.")
            }
        }
    }
}

// MARK: - Sections

extension PreferencesView {
    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: $viewModel.isDarkModeEnabled)

            Picker("Accent Color", selection: $viewModel.accentColor) {
                ForEach(AppAccentColor.allCases, id: \.self) { color in
                    Text(color.displayName).tag(color)
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Stepper(
                "Font Size: \(viewModel.fontSize)pt",
                value: $viewModel.fontSize,
                in: 10 ... 24
            )

            Toggle("Onboarding Completed", isOn: $viewModel.onboardingCompleted)
        }
    }

    private var statsSection: some View {
        Section("Statistics") {
            LabeledContent("Launch Count") {
                Text("\(viewModel.launchCount)")
            }

            Button("Simulate App Launch") {
                viewModel.incrementLaunchCount()
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Reset to Defaults", role: .destructive) {
                showResetConfirmation = true
            }
        }
    }

    private var infoSection: some View {
        Section {
            LabeledContent("Storage Backend") {
                Text("PreferenceStorage")
            }

            LabeledContent("Access Pattern") {
                Text("Synchronous")
            }

            LabeledContent("Key Prefix") {
                Text("ARCPrefs")
            }
        } header: {
            Text("Info")
        } footer: {
            Text(
                "PreferenceStorage provides synchronous access to simple key-value preferences, ideal for use in initializers."
            )
        }
    }
}

// MARK: - Preview

#Preview {
    PreferencesView(
        viewModel: PreferencesViewModel(
            preferences: PreferenceStorage(keyPrefix: "Preview.Prefs")
        )
    )
}
