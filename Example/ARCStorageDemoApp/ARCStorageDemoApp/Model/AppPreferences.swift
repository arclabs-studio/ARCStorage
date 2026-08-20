//
//  AppPreferences.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 05/02/2026.
//

import ARCStorage
import Foundation

/// Type-safe preference keys for the app.
///
/// Demonstrates the PreferenceKey protocol for synchronous key-value storage.
enum AppPreferences {
    /// Whether dark mode is enabled.
    struct DarkModeEnabled: PreferenceKey {
        static let key = "app.darkMode"
        static let defaultValue = false
    }

    /// Whether notifications are enabled.
    struct NotificationsEnabled: PreferenceKey {
        static let key = "app.notifications"
        static let defaultValue = true
    }

    /// The app's accent color.
    struct AccentColor: PreferenceKey {
        static let key = "app.accentColor"
        static let defaultValue = AppAccentColor.blue
    }

    /// Whether onboarding has been completed.
    struct OnboardingCompleted: PreferenceKey {
        static let key = "app.onboardingCompleted"
        static let defaultValue = false
    }

    /// The user's preferred font size.
    struct FontSize: PreferenceKey {
        static let key = "app.fontSize"
        static let defaultValue = 14
    }

    /// Number of app launches.
    struct LaunchCount: PreferenceKey {
        static let key = "app.launchCount"
        static let defaultValue = 0
    }
}

// MARK: - Supporting Types

/// Available accent colors for the app.
enum AppAccentColor: String, Codable, Sendable, CaseIterable {
    case blue
    case purple
    case orange
    case green
    case red

    var displayName: String {
        rawValue.capitalized
    }
}
