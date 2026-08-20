//
//  PreferencesViewModel.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 05/02/2026.
//

import ARCStorage
import Foundation

/// ViewModel for managing app preferences using PreferenceStorage.
///
/// Demonstrates synchronous preference access with type-safe keys.
/// Unlike SettingsViewModel (which uses async UserDefaultsRepository),
/// this uses synchronous PreferenceStorage for simple key-value access.
@MainActor
@Observable
final class PreferencesViewModel {
    // MARK: Public Properties

    var isDarkModeEnabled: Bool {
        didSet {
            preferences.set(isDarkModeEnabled, for: AppPreferences.DarkModeEnabled.self)
        }
    }

    var notificationsEnabled: Bool {
        didSet {
            preferences.set(notificationsEnabled, for: AppPreferences.NotificationsEnabled.self)
        }
    }

    var accentColor: AppAccentColor {
        didSet {
            preferences.set(accentColor, for: AppPreferences.AccentColor.self)
        }
    }

    var fontSize: Int {
        didSet {
            preferences.set(fontSize, for: AppPreferences.FontSize.self)
        }
    }

    var onboardingCompleted: Bool {
        didSet {
            preferences.set(onboardingCompleted, for: AppPreferences.OnboardingCompleted.self)
        }
    }

    private(set) var launchCount: Int

    // MARK: Private Properties

    private let preferences: PreferenceStorageProtocol

    // MARK: Initialization

    /// Creates a new preferences view model.
    ///
    /// Note: All reads happen synchronously in init - no async required!
    init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
        self.preferences = preferences

        // Synchronous reads - perfect for init!
        isDarkModeEnabled = preferences.get(AppPreferences.DarkModeEnabled.self)
        notificationsEnabled = preferences.get(AppPreferences.NotificationsEnabled.self)
        accentColor = preferences.get(AppPreferences.AccentColor.self)
        fontSize = preferences.get(AppPreferences.FontSize.self)
        onboardingCompleted = preferences.get(AppPreferences.OnboardingCompleted.self)
        launchCount = preferences.get(AppPreferences.LaunchCount.self)
    }

    // MARK: Public Functions

    /// Increments and persists the launch count.
    func incrementLaunchCount() {
        launchCount += 1
        preferences.set(launchCount, for: AppPreferences.LaunchCount.self)
    }

    /// Resets all preferences to their default values.
    func resetToDefaults() {
        preferences.remove(AppPreferences.DarkModeEnabled.self)
        preferences.remove(AppPreferences.NotificationsEnabled.self)
        preferences.remove(AppPreferences.AccentColor.self)
        preferences.remove(AppPreferences.FontSize.self)
        preferences.remove(AppPreferences.OnboardingCompleted.self)
        preferences.remove(AppPreferences.LaunchCount.self)

        // Reload defaults
        isDarkModeEnabled = preferences.get(AppPreferences.DarkModeEnabled.self)
        notificationsEnabled = preferences.get(AppPreferences.NotificationsEnabled.self)
        accentColor = preferences.get(AppPreferences.AccentColor.self)
        fontSize = preferences.get(AppPreferences.FontSize.self)
        onboardingCompleted = preferences.get(AppPreferences.OnboardingCompleted.self)
        launchCount = preferences.get(AppPreferences.LaunchCount.self)
    }

    /// Checks if a specific preference has been set (not using default).
    func hasCustomValue(for key: (some PreferenceKey).Type) -> Bool {
        preferences.hasValue(for: key)
    }
}
