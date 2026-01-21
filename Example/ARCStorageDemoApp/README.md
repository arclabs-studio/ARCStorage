# ARCStorageDemoApp

Demo application for **ARCStorage** package.

## Requirements

- Xcode 16.0+
- iOS 18.0+
- Swift 6.0

## Running the Example

1. Open `ARCStorageDemoApp.xcodeproj` in Xcode
2. The ARCStorage package is referenced locally from the parent directory (`../..`)
3. Select an iOS simulator and press Run (Cmd+R)

## Features Demonstrated

### InMemoryRepository

The Notes tab demonstrates `InMemoryRepository<Note>` with:

- **Create**: Add new notes with title, content, and color
- **Read**: List all notes with pinned items first
- **Update**: Edit note details and toggle pin status
- **Delete**: Swipe to delete notes
- **Cache Invalidation**: Pull to refresh clears cache and reloads

### KeychainRepository (NEW)

The Secure tab demonstrates `KeychainRepository<AuthToken>` with:

- **Secure Storage**: Tokens encrypted in iOS Keychain
- **Security Levels**: Using `KeychainAccessibility.whenUnlockedThisDeviceOnly`
- **Token Management**: Generate, refresh, and delete tokens
- **Expiration Tracking**: Shows token validity and time remaining

### UserDefaultsRepository

The Settings tab demonstrates `UserDefaultsRepository<AppSettings>` with:

- **Persistence**: Settings are saved to UserDefaults
- **Cache-Aside Pattern**: Settings are cached in memory with 5-minute TTL
- **Reset**: Clear settings and restore defaults

### Architecture Patterns

- **Repository Pattern**: Abstracts storage implementation
- **MVVM**: ViewModels manage state and business logic
- **Dependency Injection**: Repositories injected into ViewModels
- **Swift 6 Concurrency**: Full async/await with strict concurrency

### Modern SwiftUI APIs (iOS 18+)

- **Tab**: New declarative tab API for `TabView`
- **@Observable**: Observation framework macro for ViewModels
- **@Bindable**: Property wrapper for observable object bindings

## Project Structure

```
ARCStorageDemoApp/
├── ARCStorageDemoApp.swift  # App entry point
├── ContentView.swift        # Main tab view
├── Model/
│   ├── Note.swift           # Note entity
│   ├── AppSettings.swift    # Settings entity
│   └── AuthToken.swift      # Auth token entity (Keychain)
├── ViewModel/
│   ├── NotesViewModel.swift     # Notes business logic
│   ├── SettingsViewModel.swift  # Settings business logic
│   └── AuthViewModel.swift      # Auth/Keychain business logic
├── Views/
│   ├── NoteListView.swift   # Notes list
│   ├── NoteDetailView.swift # Note editor
│   ├── AddNoteView.swift    # New note form
│   ├── SettingsView.swift   # Settings form
│   └── AuthView.swift       # Secure storage demo
└── Assets.xcassets          # App assets
```

## Key Implementation Details

### Using @Observable

ViewModels use the new `@Observable` macro instead of `ObservableObject`:

```swift
@MainActor
@Observable
final class NotesViewModel {
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    // ...
}
```

### Repository Initialization

```swift
// InMemory for notes (volatile storage)
let notesRepository = InMemoryRepository<Note>()

// UserDefaults for settings (persistent storage)
let settingsRepository = UserDefaultsRepository<AppSettings>(
    keyPrefix: "ARCStorageDemoApp.Settings"
)

// Keychain for auth tokens (secure storage with security level)
let authViewModel = AuthViewModel(
    securityLevel: .whenUnlockedThisDeviceOnly,
    service: "com.arclabs.arcstoragedemoapp.auth"
)
```

### Async Operations

All repository operations are async:

```swift
func loadNotes() async {
    isLoading = true
    do {
        notes = try await repository.fetchAll()
    } catch {
        errorMessage = error.localizedDescription
    }
    isLoading = false
}
```

## License

MIT License - see LICENSE file in the package root.

## Author

**ARC Labs Studio**
