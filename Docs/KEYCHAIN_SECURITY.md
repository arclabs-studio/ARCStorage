# Keychain Security Guide

## Overview

ARCStorage provides `KeychainStorage<T>` and `KeychainRepository<T>` for storing sensitive data encrypted in the system Keychain. Use these for API keys, auth tokens, passwords, and any data that should not be stored in plain text on disk.

## When to Use the Keychain

| Data type | Recommended storage |
|---|---|
| API keys, OAuth tokens | `KeychainRepository` |
| Passwords, credentials | `KeychainRepository` |
| Session tokens (JWT, refresh tokens) | `KeychainRepository` |
| Non-sensitive user preferences | `UserDefaultsRepository` |
| Business data (models, records) | `SwiftDataRepository` |
| Temporary test fixtures | `InMemoryRepository` |

## Quick Start

### 1. Define a `Codable & Sendable & Identifiable` model

```swift
struct APIKey: Codable, Sendable, Identifiable {
    let id: String       // semantic identifier, e.g. "openai_api_key"
    let value: String    // the secret value
    let createdAt: Date
}
```

### 2. Create a repository

```swift
let apiKeyRepo = KeychainRepository<APIKey>(
    service: "com.myapp.apikeys",
    accessibility: .whenUnlockedThisDeviceOnly   // no iCloud sync
)
```

### 3. Save, fetch, and delete

```swift
// Save
let key = APIKey(id: "openai", value: "sk-...", createdAt: .now)
try await apiKeyRepo.save(key)

// Fetch
let fetched = try await apiKeyRepo.fetch(id: "openai")

// Delete
try await apiKeyRepo.delete(id: "openai")
```

## Accessibility Levels

`KeychainAccessibility` maps directly to Apple's `kSecAttrAccessible` constants.

| Case | iCloud Sync | Background Access | Recommended for |
|---|---|---|---|
| `.whenUnlocked` (default) | ✅ Yes | ❌ No | General secure data |
| `.whenUnlockedThisDeviceOnly` | ❌ No | ❌ No | **API keys, device-specific tokens** |
| `.afterFirstUnlock` | ✅ Yes | ✅ Yes | Background refresh tokens |
| `.afterFirstUnlockThisDeviceOnly` | ❌ No | ✅ Yes | Background tokens, no sync |
| `.whenPasscodeSetThisDeviceOnly` | ❌ No | ❌ No | Highest security — requires device passcode |

### Choosing the right level

**API keys for third-party services (OpenAI, Stripe, etc.):** Use `.whenUnlockedThisDeviceOnly`. These keys are per-developer or per-installation and should not sync to other devices via iCloud.

**Auth tokens that should follow the user across devices:** Use `.whenUnlocked` (default). iCloud Keychain syncs the item so the user stays logged in on all their devices.

**Background refresh tokens:** Use `.afterFirstUnlock` or `.afterFirstUnlockThisDeviceOnly`. The app needs to access tokens during background fetch, which happens while the device is locked (after the first unlock since boot).

**Highly sensitive credentials requiring passcode:** Use `.whenPasscodeSetThisDeviceOnly`. The item is destroyed if the user removes their device passcode. Note: this will fail on simulators and devices without a passcode set.

## Common Patterns

### Auth tokens

```swift
struct AuthToken: Codable, Sendable, Identifiable {
    let id: String            // e.g. "user_auth_token"
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

let tokenRepo = KeychainRepository<AuthToken>(
    service: "com.myapp.auth",
    accessibility: .whenUnlockedThisDeviceOnly
)
```

### User credentials

```swift
struct UserCredential: Codable, Sendable, Identifiable {
    let id: String            // e.g. "primary_account"
    let username: String
    let passwordHash: String  // Never store passwords in plain text
}

let credRepo = KeychainRepository<UserCredential>(
    service: "com.myapp.credentials",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
```

### Multiple API keys

```swift
struct APIKey: Codable, Sendable, Identifiable {
    let id: String     // e.g. "openai", "stripe", "mapbox"
    let key: String
}

let keyRepo = KeychainRepository<APIKey>(
    service: "com.myapp.apikeys",
    accessibility: .whenUnlockedThisDeviceOnly
)

// Save multiple keys
try await keyRepo.save(APIKey(id: "openai", key: "sk-..."))
try await keyRepo.save(APIKey(id: "stripe", key: "sk_live_..."))

// Fetch a specific key
let openAIKey = try await keyRepo.fetch(id: "openai")
```

## Cache Behavior

`KeychainRepository` uses the cache-aside pattern with an LRU cache (default: 100 items, 5-minute TTL). This avoids redundant Keychain reads, which are more expensive than memory lookups.

```swift
// Default cache (100 items, 5 min TTL)
let repo = KeychainRepository<APIKey>(service: "com.myapp.keys")

// Aggressive cache (500 items, 1 hour TTL) — for rarely changing credentials
let repo = KeychainRepository<APIKey>(
    service: "com.myapp.keys",
    cachePolicy: .aggressive
)

// No cache — always reads from Keychain
let repo = KeychainRepository<APIKey>(
    service: "com.myapp.keys",
    cachePolicy: .noCache
)
```

Invalidate the cache manually when you know data changed from an external source:

```swift
await repo.invalidateCache()
```

## Access Groups (Shared Keychain)

Share Keychain items between your app and its extensions (Share Extension, Widget, etc.) using an access group:

```swift
let sharedRepo = KeychainRepository<AuthToken>(
    service: "com.myapp.auth",
    accessGroup: "TEAMID.com.myapp.shared",   // matches entitlement
    accessibility: .whenUnlockedThisDeviceOnly
)
```

The access group must be listed in your app's `Keychain Sharing` entitlement in Xcode (Signing & Capabilities > Keychain Sharing).

## Entity Requirements

Entities stored in `KeychainStorage`/`KeychainRepository` must conform to:

```swift
T: Codable & Sendable & Identifiable
where T.ID: LosslessStringConvertible & Sendable & Hashable
```

The `id` is stored as the Keychain `kSecAttrAccount`. Common ID types that satisfy `LosslessStringConvertible`:
- `String`
- `UUID` (via its `LosslessStringConvertible` conformance in Foundation)
- `Int`

## Error Handling

All operations throw `StorageError`:

```swift
do {
    let key = try await keyRepo.fetch(id: "openai")
} catch StorageError.fetchFailed(let underlying) {
    // Keychain read error (e.g. device locked, access denied)
} catch StorageError.entityNotFound(let id) {
    // Item does not exist in Keychain
} catch StorageError.saveFailed(let underlying) {
    // Keychain write error
}
```

## Security Notes

- **Never log or print sensitive Keychain values.** Even in DEBUG builds, avoid logging API keys or tokens.
- **Never store passwords in plain text.** Use a hashing library (CryptoKit) before storing passwords; better yet, use `ASAuthorizationAppleIDProvider` or the platform's authentication system.
- **Prefer `ThisDeviceOnly` for non-user-facing secrets.** API keys for third-party services are credentials of your app, not the user — they should not roam via iCloud Keychain.
- **Use `.whenPasscodeSetThisDeviceOnly` for payment credentials.** Items are automatically destroyed if the device passcode is removed, providing protection against device theft.
- **The Keychain is encrypted at rest** by the OS using the device's hardware Secure Enclave (on supported devices). ARCStorage adds no additional encryption layer on top.

## Platform Behavior Notes

- **macOS:** `SecItemDelete` removes one item per call. ARCStorage's `deleteAll()` loops until all items are removed.
- **iOS Simulator:** Full Keychain access is available. `.whenPasscodeSetThisDeviceOnly` requires setting a simulator passcode in Settings.
- **Swift Package tests (macOS):** `SecItemCopyMatching` with `kSecMatchLimitAll` + `kSecReturnData` returns `errSecParam` on macOS without entitlements. ARCStorage's `fetchAll()` uses a two-step approach (accounts first, data per account) to work around this limitation.
