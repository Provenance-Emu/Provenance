import Foundation
import PVLogging

/// Manages partial updates to retroarch.cfg across app versions.
/// Instead of nuking the whole config, this applies only the keys that changed
/// for a given version, preserving all user customizations.
@MainActor
enum RetroArchConfigMigrator {

    private static let lastMigrationVersionKey = "retroarch_config_migration_version"

    struct Migration {
        let appVersion: String
        let key: String
        let value: String
        let reason: String
    }

    // MARK: - Migration Definitions

    /// Add new migrations at the end. Each entry sets a single key.
    /// Users who already ran a migration won't see it again.
    static let migrations: [Migration] = [
        // v3.4.0 — Disable notification spam that confuses casual users
        Migration(appVersion: "3.4.0", key: "notification_show_fast_forward", value: "false",
                  reason: "Disable fast-forward notification spam"),
        Migration(appVersion: "3.4.0", key: "notification_show_save_state", value: "false",
                  reason: "Disable save-state notification spam"),
        Migration(appVersion: "3.4.0", key: "notification_show_screenshot", value: "false",
                  reason: "Disable screenshot notification spam"),
        Migration(appVersion: "3.4.0", key: "notification_show_config_override_load", value: "false",
                  reason: "Disable config-override notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_remap_load", value: "false",
                  reason: "Disable remap-load notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_refresh_rate", value: "false",
                  reason: "Disable refresh-rate notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_patch_applied", value: "false",
                  reason: "Disable patch-applied notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_when_menu_is_alive", value: "false",
                  reason: "Disable in-menu notifications"),
        Migration(appVersion: "3.4.0", key: "notification_show_set_initial_disk", value: "false",
                  reason: "Disable initial-disk notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_autoconfig", value: "false",
                  reason: "Disable autoconfig notification"),
        Migration(appVersion: "3.4.0", key: "notification_show_autoconfig_fails", value: "false",
                  reason: "Disable autoconfig-fail notification")
    ]

    // MARK: - Public API

    /// Run any pending migrations against the active retroarch.cfg.
    /// Safe to call on every launch — already-applied versions are skipped.
    static func applyPendingMigrations() async {
        let manager = PVRetroArchCoreManager.shared
        guard let url = manager.activeConfigURL,
              FileManager.default.fileExists(atPath: url.path) else {
            DLOG("No retroarch.cfg found, skipping migrations")
            return
        }

        let lastVersion = UserDefaults.standard.string(forKey: lastMigrationVersionKey) ?? "0.0.0"
        let pending = migrations.filter { compareVersions($0.appVersion, isGreaterThan: lastVersion) }

        guard !pending.isEmpty else {
            DLOG("No pending RA config migrations")
            return
        }

        ILOG("Applying \(pending.count) RetroArch config migrations")

        do {
            var fullConfig = await manager.parseConfigFile(at: url)

            for migration in pending {
                let oldValue = fullConfig[migration.key]
                fullConfig[migration.key] = "\"\(migration.value)\""
                ILOG("Migration: \(migration.key) \(oldValue ?? "nil") -> \"\(migration.value)\" (\(migration.reason))")
            }

            let sortedKeys = fullConfig.keys.sorted()
            let content = sortedKeys.map { "\($0) = \(fullConfig[$0] ?? "")" }.joined(separator: "\n")
            try content.write(to: url, atomically: true, encoding: .utf8)

            // Record the highest version we applied
            if let maxVersion = pending.map(\.appVersion).max(by: { compareVersions($1, isGreaterThan: $0) }) {
                UserDefaults.standard.set(maxVersion, forKey: lastMigrationVersionKey)
            }

            ILOG("RetroArch config migrations applied successfully")
        } catch {
            ELOG("Failed to apply RA config migrations: \(error)")
        }
    }

    // MARK: - Version Comparison

    /// Returns true if `lhs` is strictly greater than `rhs` using semantic versioning.
    private static func compareVersions(_ lhs: String, isGreaterThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(lhsParts.count, rhsParts.count)

        for i in 0..<count {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }
}
