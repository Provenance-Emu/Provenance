/// File-system storage helper for the PVControllerDSU module.
///
/// All disk I/O in this module MUST go through `DSUFileStorage.baseURL`.
///
/// ## Why Caches, not Documents?
///
/// - **tvOS**: The `Documents` directory is **not writable** by third-party apps on
///   tvOS — writing there will fail silently or crash at runtime.  `Caches` is the
///   designated writable directory on tvOS for regeneratable data.
/// - **All other Apple platforms** (iOS, macOS, Mac Catalyst, visionOS, watchOS):
///   DSU protocol state (discovered peers, connection history) is ephemeral and should
///   never count against the user's iCloud backup quota or device storage warning.
///   `Caches` is the semantically correct location.
///
/// **Never** pass `.documentDirectory` to `FileManager` anywhere in this module.

import Foundation

/// Provides the base directory URL for DSU module file storage.
///
/// - Important: **Always** use `DSUFileStorage.baseURL` (or a subdirectory of
///   it) when writing files from this module. Never pass `.documentDirectory`
///   to `FileManager` directly — that directory is restricted on tvOS and
///   will fail at runtime.
///
/// - Returns: `<Caches>/PVControllerDSU/` on every supported Apple platform.
///   The directory is **not** created automatically; call
///   `FileManager.default.createDirectory(at:withIntermediateDirectories:)`
///   before writing files.
public enum DSUFileStorage {

    /// The base `URL` for PVControllerDSU file storage.
    ///
    /// Maps to `<Caches>/PVControllerDSU/` on every supported platform,
    /// including tvOS where `Documents` is not writable.
    public static var baseURL: URL {
        // `.cachesDirectory` with `.userDomainMask` always returns at least one URL on
        // every supported Apple platform (iOS, tvOS, macOS, Mac Catalyst, visionOS,
        // watchOS). The force-unwrap is intentional and safe here — DSU state is
        // transient and Caches is the only correct directory for this data.
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("PVControllerDSU", isDirectory: true)
    }
}
