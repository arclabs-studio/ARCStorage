import ARCLogger
import Foundation

/// Reads build-time configuration values from a bundle's `Info.plist`.
///
/// Use this for **client-public** configuration that is injected at build time
/// from an `.xcconfig` file (for example, the Firebase or RevenueCat SDK keys).
/// These values are not secrets — they ship inside the app binary by design and
/// are protected on the provider side (Firebase Security Rules + App Check,
/// RevenueCat server-side receipt validation), not by being hidden in the app.
///
/// For **real secrets** (third-party API keys for server-to-server calls, signing
/// keys, `.p8` files) do *not* use this type: those must never reach the device.
/// Proxy them through a backend (Cloud Function + Secret Manager).
///
/// ## Topics
/// ### Reading configuration
/// - ``string(_:bundle:)``
/// ### Light obfuscation (defense-in-depth only)
/// - ``deobfuscated(_:)``
///
/// ## Example
/// ```swift
/// // Build setting RC_API_KEY is injected into Info.plist via xcconfig.
/// let apiKey = ConfigurationValue.string("RC_API_KEY") ?? ""
/// ```
public enum ConfigurationValue {
    private static let logger = ARCLogger(category: "ConfigurationValue")

    /// Reads a non-empty string value from a bundle's `Info.plist`.
    ///
    /// Returns `nil` (and logs a warning) when the key is absent or maps to an
    /// empty string — which typically means the corresponding build setting was
    /// not provided (for example, a missing `Secrets-*.xcconfig` during local
    /// development). Callers should treat `nil` as "feature not configured".
    ///
    /// - Parameters:
    ///   - key: The `Info.plist` key, matching the build setting name.
    ///   - bundle: The bundle to read from. Defaults to ``Foundation/Bundle/main``.
    /// - Returns: The configured value, or `nil` if missing or empty.
    public static func string(_ key: String, bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            logger.warning("Missing Info.plist configuration value", metadata: ["key": .public(key)])
            return nil
        }
        return value
    }

    /// Reconstructs a string from an obfuscated byte array.
    ///
    /// Pair this with the `key-obfuscator.swift` codegen tool in ARCDevTools,
    /// which emits an array literal like `[0x73 - 0x2E, 0xC6 - 0x53, …]` for a
    /// given input string. Commit the generated literal in your app (not in this
    /// package) and reconstruct it at runtime with this method.
    ///
    /// - Warning: This is **light obfuscation** — a speed-bump against casual
    ///   `strings`-style binary scraping, *not* a secret store. Anything shipped
    ///   in an app binary is recoverable by a motivated attacker. Never use this
    ///   for server-side secrets; only ever for values that are already
    ///   client-public and protected provider-side.
    ///
    /// - Parameter bytes: The obfuscated UTF-8 bytes.
    /// - Returns: The decoded string, or `nil` if the bytes are not valid UTF-8.
    public static func deobfuscated(_ bytes: [UInt8]) -> String? {
        guard let value = String(data: Data(bytes), encoding: .utf8) else {
            logger.error("Failed to decode obfuscated configuration value")
            return nil
        }
        return value
    }
}
