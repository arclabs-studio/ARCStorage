//
//  AuthViewModel.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 05/01/2026.
//

import ARCStorage
import Foundation

/// ViewModel for managing authentication tokens using KeychainRepository.
///
/// Demonstrates secure storage with `KeychainAccessibility` levels.
@MainActor
@Observable
final class AuthViewModel {
    // MARK: Public Properties

    /// Current authentication token, if any.
    private(set) var token: AuthToken?

    /// Whether a token operation is in progress.
    private(set) var isLoading = false

    /// Last error message, if any.
    private(set) var errorMessage: String?

    /// The current security level being used.
    let securityLevel: KeychainAccessibility

    /// Human-readable security level description.
    var securityLevelDescription: String {
        switch securityLevel {
        case .whenUnlocked:
            return "When Unlocked (Default)"
        case .whenUnlockedThisDeviceOnly:
            return "When Unlocked (This Device Only)"
        case .afterFirstUnlock:
            return "After First Unlock"
        case .afterFirstUnlockThisDeviceOnly:
            return "After First Unlock (This Device Only)"
        case .whenPasscodeSetThisDeviceOnly:
            return "When Passcode Set (Most Secure)"
        }
    }

    // MARK: Private Properties

    private let repository: KeychainRepository<AuthToken>

    // MARK: Initialization

    /// Creates a new AuthViewModel with the specified security level.
    ///
    /// - Parameters:
    ///   - securityLevel: The Keychain accessibility level to use
    ///   - service: The Keychain service identifier
    init(
        securityLevel: KeychainAccessibility = .whenUnlockedThisDeviceOnly,
        service: String = "com.arclabs.exampleapp.auth"
    ) {
        self.securityLevel = securityLevel
        repository = KeychainRepository<AuthToken>(
            service: service,
            accessibility: securityLevel
        )
    }

    // MARK: Public Methods

    /// Loads the stored authentication token.
    func loadToken() async {
        isLoading = true
        errorMessage = nil

        do {
            token = try await repository.fetch(id: "main")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Saves or updates the authentication token.
    func saveToken(_ newToken: AuthToken) async {
        isLoading = true
        errorMessage = nil

        do {
            try await repository.save(newToken)
            token = newToken
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Generates and saves a new demo token.
    func generateDemoToken() async {
        let demoToken = AuthToken.demo
        await saveToken(demoToken)
    }

    /// Deletes the stored token (logout).
    func deleteToken() async {
        guard token != nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await repository.delete(id: "main")
            token = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refreshes the token with a new expiration time.
    func refreshToken() async {
        guard var currentToken = token else { return }

        currentToken.token = "refreshed_\(UUID().uuidString.prefix(8))"
        currentToken.expiresAt = Date().addingTimeInterval(3600)

        await saveToken(currentToken)
    }
}
