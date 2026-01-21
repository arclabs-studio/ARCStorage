//
//  AuthToken.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 05/01/2026.
//

import Foundation

/// Represents an authentication token stored securely in the Keychain.
///
/// Demonstrates `KeychainStorage` with `KeychainAccessibility` security levels.
struct AuthToken: Codable, Identifiable, Sendable {
    /// Unique identifier for the token.
    let id: String

    /// The actual token value.
    var token: String

    /// When the token was issued.
    let issuedAt: Date

    /// When the token expires.
    var expiresAt: Date

    /// The associated user email.
    var userEmail: String

    /// Whether the token is still valid.
    var isValid: Bool {
        Date() < expiresAt
    }

    /// Time remaining until expiration.
    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    /// Default token for demo purposes.
    static let demo = AuthToken(
        id: "main",
        token: "demo_token_\(UUID().uuidString.prefix(8))",
        issuedAt: Date(),
        expiresAt: Date().addingTimeInterval(3600), // 1 hour
        userEmail: "demo@example.com"
    )
}
