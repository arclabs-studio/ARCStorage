import Foundation

/// Helper utilities for data migration.
///
/// Provides common migration operations and utilities.
public enum MigrationHelper {
    /// Detects the current schema version.
    ///
    /// - Returns: Current version string
    public static func detectCurrentVersion() -> String {
        // In a real implementation, this would check UserDefaults or metadata
        UserDefaults.standard.string(forKey: "ARCStorage.SchemaVersion") ?? "1.0"
    }

    /// Saves the current schema version.
    ///
    /// - Parameter version: Version to save
    public static func saveCurrentVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: "ARCStorage.SchemaVersion")
    }

    /// Checks if migration is needed.
    ///
    /// - Parameters:
    ///   - currentVersion: Current schema version
    ///   - targetVersion: Target schema version
    /// - Returns: Whether migration is needed
    public static func needsMigration(
        from currentVersion: String,
        to targetVersion: String
    ) -> Bool {
        currentVersion != targetVersion
    }

    /// Creates a backup before migration.
    ///
    /// - Parameter storageURL: URL of storage to backup
    /// - Returns: URL of backup
    public static func createBackup(of storageURL: URL) throws -> URL {
        let backupURL = storageURL.deletingLastPathComponent()
            .appendingPathComponent("backup_\(UUID().uuidString)")

        try FileManager.default.copyItem(at: storageURL, to: backupURL)
        return backupURL
    }

    /// Restores from a backup.
    ///
    /// - Parameters:
    ///   - backupURL: URL of backup
    ///   - storageURL: URL to restore to
    public static func restoreBackup(from backupURL: URL, to storageURL: URL) throws {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }
        try FileManager.default.copyItem(at: backupURL, to: storageURL)
    }

    /// Deletes a backup.
    ///
    /// - Parameter backupURL: URL of backup to delete
    public static func deleteBackup(at backupURL: URL) throws {
        try FileManager.default.removeItem(at: backupURL)
    }
}
