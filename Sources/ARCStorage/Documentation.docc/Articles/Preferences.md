# Preferences Storage

Store simple configuration values synchronously with type-safe keys.

## Overview

`PreferenceStorage` provides a lightweight, synchronous API for storing simple preferences and configuration values. Unlike ``UserDefaultsRepository`` which is async and designed for entity collections, `PreferenceStorage` is optimized for:

- **Synchronous access** - Works in `init()` and other non-async contexts
- **Simple key-value pairs** - No `Identifiable` conformance required
- **Type safety** - Compile-time checked keys with default values

### When to Use PreferenceStorage

| Use Case | Recommended API |
|----------|-----------------|
| Single enum/bool/string preference | ``PreferenceStorage`` |
| Configuration read during `init()` | ``PreferenceStorage`` |
| Collection of entities with IDs | ``UserDefaultsRepository`` |
| Complex queries with predicates | ``UserDefaultsRepository`` |

## Defining Preference Keys

Create type-safe keys by implementing the ``PreferenceKey`` protocol:

```swift
enum AppPreferences {
    struct DarkModeEnabled: PreferenceKey {
        static let key = "app.darkMode"
        static let defaultValue = false
    }

    struct SelectedEnvironment: PreferenceKey {
        static let key = "app.environment"
        static let defaultValue = Environment.production
    }

    struct OnboardingCompleted: PreferenceKey {
        static let key = "app.onboardingCompleted"
        static let defaultValue = false
    }
}

enum Environment: String, Codable, Sendable {
    case production
    case staging
    case development
}
```

Each key defines:
- **`key`**: The storage key string (combined with prefix to form the actual UserDefaults key)
- **`defaultValue`**: Returned when no value is stored or decode fails

## Basic Usage

```swift
let preferences = PreferenceStorage()

// Read (returns default if not set)
let isDarkMode = preferences.get(AppPreferences.DarkModeEnabled.self)

// Write
preferences.set(true, for: AppPreferences.DarkModeEnabled.self)

// Check existence
if preferences.hasValue(for: AppPreferences.OnboardingCompleted.self) {
    // User has seen onboarding
}

// Remove (reverts to default)
preferences.remove(AppPreferences.DarkModeEnabled.self)
```

## Synchronous Initialization

The primary advantage of `PreferenceStorage` is synchronous access, enabling use in initializers:

```swift
final class AppCoordinator {
    private let preferences: PreferenceStorageProtocol
    private let environment: Environment

    init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
        self.preferences = preferences

        // Synchronous - works in init!
        self.environment = preferences.get(AppPreferences.SelectedEnvironment.self)

        if !preferences.get(AppPreferences.OnboardingCompleted.self) {
            showOnboarding()
        }
    }
}
```

## Using with ViewModels

```swift
@Observable
final class SettingsViewModel {
    private let preferences: PreferenceStorageProtocol

    var isDarkModeEnabled: Bool {
        didSet {
            preferences.set(isDarkModeEnabled, for: AppPreferences.DarkModeEnabled.self)
        }
    }

    init(preferences: PreferenceStorageProtocol = PreferenceStorage()) {
        self.preferences = preferences
        self.isDarkModeEnabled = preferences.get(AppPreferences.DarkModeEnabled.self)
    }
}
```

## Testing with MockPreferenceStorage

Use ``MockPreferenceStorage`` for unit testing:

```swift
@Test("ViewModel loads initial preference value")
func viewModel_loadsInitialValue() {
    // Given
    let mock = MockPreferenceStorage()
    mock.setMockValue(true, for: AppPreferences.DarkModeEnabled.self)

    // When
    let viewModel = SettingsViewModel(preferences: mock)

    // Then
    #expect(viewModel.isDarkModeEnabled == true)
    #expect(mock.getCallCount == 1)
}

@Test("ViewModel persists changes")
func viewModel_persistsChanges() {
    // Given
    let mock = MockPreferenceStorage()
    let viewModel = SettingsViewModel(preferences: mock)

    // When
    viewModel.isDarkModeEnabled = true

    // Then
    #expect(mock.setCallCount == 1)
    #expect(mock.get(AppPreferences.DarkModeEnabled.self) == true)
}
```

### Mock Call Tracking

`MockPreferenceStorage` tracks all operations:

- `getCallCount` - Number of `get` calls
- `setCallCount` - Number of `set` calls
- `removeCallCount` - Number of `remove` calls
- `hasValueCallCount` - Number of `hasValue` calls
- `lastAccessedKey` - The last key accessed

## Key Prefixing

By default, keys are prefixed with `"ARCPrefs"` to avoid collisions:

```swift
// Default prefix
let prefs1 = PreferenceStorage() // Keys: "ARCPrefs.app.darkMode"

// Custom prefix
let prefs2 = PreferenceStorage(keyPrefix: "MyApp") // Keys: "MyApp.app.darkMode"
```

This ensures `PreferenceStorage` keys don't conflict with ``UserDefaultsStorage`` keys (which use `"ARCStorage"` by default).

## Complex Codable Values

Any `Codable & Sendable` type works as a preference value:

```swift
struct UserSettings: Codable, Sendable {
    var fontSize: Int
    var accentColor: String
    var recentSearches: [String]
}

enum AppPreferences {
    struct Settings: PreferenceKey {
        static let key = "user.settings"
        static let defaultValue = UserSettings(
            fontSize: 14,
            accentColor: "blue",
            recentSearches: []
        )
    }
}
```

## Topics

### Protocols

- ``PreferenceKey``
- ``PreferenceStorageProtocol``

### Implementations

- ``PreferenceStorage``
- ``MockPreferenceStorage``
