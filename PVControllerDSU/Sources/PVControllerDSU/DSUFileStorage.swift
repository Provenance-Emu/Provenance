/// File-system storage helper for the PVControllerDSU module.
///
/// All disk I/O in this module MUST go through `DSUFileStorage.baseURL`.
///
/// On tvOS the Documents directory is heavily restricted and cannot be used
/// for app-generated data.  The Caches directory is the correct location for
/// transient DSU data (discovered peers, connection history) that can be
/// regenerated on demand.  Using Caches is also correct on iOS and macOS —
/// DSU protocol state is ephemeral and should never count against the user's
/// iCloud or device backup quota.

import Foundation

/// Provides the base directory URL for DSU module file storage.
///
/// - Important: **Always** use `DSUFileStorage.baseURL` (or a subdirectory of
///   it) when writing files from this module. Never pass `.documentDirectory`
///   to `FileManager` directly — that directory is restricted on tvOS and
///   would fail at runtime.
public enum DSUFileStorage {

    /// The base `URL` for PVControllerDSU file storage.
    ///
    /// Returns `<Caches>/PVControllerDSU/` on every supported Apple platform.
    /// The directory is not created automatically; call
    /// `FileManager.default.createDirectory(at:withIntermediateDirectories:)`
    /// before writing files.
    public static var baseURL: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!                                         // always present on Apple platforms
            .appendingPathComponent("PVControllerDSU", isDirectory: true)
    }
}
