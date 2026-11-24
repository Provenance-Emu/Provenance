//
//  DiskSpace.swift
//  PVLibrarySharing
//
//  Refuses a copy that cannot fit before any of it is downloaded.
//

import Foundation

public enum DiskSpace {
    /// Kept free beyond the copy, so the importer and the system have room to work.
    public static let reserve: Int64 = 256 * 1024 * 1024

    /// Free bytes on the volume holding `url`, or nil when the system won't say.
    /// `url` need not exist yet: its nearest existing parent is asked.
    public static func available(at url: URL) -> Int64? {
        var probe = url.standardizedFileURL
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        #if os(tvOS) || os(watchOS)
        return (try? probe.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity.map(Int64.init)
        #else
        // Counts space the system can free by purging caches, which a plain capacity read leaves out.
        return (try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
        #endif
    }

    /// Throws `notEnoughSpace` when `needed` plus the reserve does not fit in `available`.
    /// An unknown capacity lets the copy try: refusing on a guess would be worse.
    public static func require(_ needed: Int64, available: Int64?) throws {
        guard let available, needed > 0, needed > available - reserve else { return }
        throw LibrarySharingError.notEnoughSpace(needed: needed, available: max(0, available))
    }
}
