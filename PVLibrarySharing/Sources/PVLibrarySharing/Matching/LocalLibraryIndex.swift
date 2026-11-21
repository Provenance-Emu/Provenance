//
//  LocalLibraryIndex.swift
//  PVLibrarySharing
//
//  The "In your library" badge (spec §3.4).
//

import Foundation
import PVSystems

/// One game in Provenance's own library, reduced to what matching needs.
/// Built from `PVGame` by the app; no Realm here.
public struct LocalLibraryEntry: Sendable, Hashable {
    /// `PVGame.md5Hash`. Provenance stores it upper-case; any case is accepted.
    public var md5: String
    public var systemIdentifier: SystemIdentifier
    /// Bytes, or 0 when unknown.
    public var sizeBytes: Int64
    /// False for CD sets and anything else whose MD5 isn't the image's own.
    public var isSingleFileImage: Bool
    /// False when the library lists the game but its file is not on this device: an
    /// iCloud entry that was never downloaded, or a file the system purged.
    public var isOnDisk: Bool

    public init(md5: String, systemIdentifier: SystemIdentifier, sizeBytes: Int64, isSingleFileImage: Bool, isOnDisk: Bool = true) {
        self.md5 = md5
        self.systemIdentifier = systemIdentifier
        self.sizeBytes = sizeBytes
        self.isSingleFileImage = isSingleFileImage
        self.isOnDisk = isOnDisk
    }

    /// Extensions whose MD5 in Provenance is not the image's own. A `.cue`/`.m3u`/`.gdi`
    /// game is keyed by its index text (imported before `MultiFileSetIdentity`) or by
    /// one data track, so neither can match a peer's MD5 for the whole image.
    public static let multiFileIndexExtensions: Set<String> = ["cue", "m3u", "gdi", "ccd", "toc"]

    /// True when a game's MD5 can be compared with a peer's: one primary file
    /// with no related files and no index extension.
    public static func isSingleFileImage(primaryFileExtension: String, relatedFileCount: Int) -> Bool {
        relatedFileCount == 0 && !multiFileIndexExtensions.contains(primaryFileExtension.lowercased())
    }
}

/// Answers "is this remote item already in my library?" by MD5.
///
/// Best effort, by design: MD5s agree only for single-file, headerless images
/// (GC `.iso`/`.rvz`, DC `.chd`/`.cdi`). A match needs the same system, the
/// same MD5 (case-insensitive), and the same size when both sides know it.
/// After a copy lands, the importer's own MD5 check handles de-duplication.
public struct LocalLibraryIndex: Sendable {
    private struct Key: Hashable {
        let system: SystemIdentifier
        let md5: String
    }

    /// Games whose file is on this device.
    private var sizes: [Key: Set<Int64>] = [:]
    /// Games the library lists without a file on this device.
    private var missingSizes: [Key: Set<Int64>] = [:]

    public init(entries: [LocalLibraryEntry]) {
        for entry in entries where entry.isSingleFileImage {
            let key = Key(system: entry.systemIdentifier, md5: entry.md5.uppercased())
            if entry.isOnDisk {
                sizes[key, default: []].insert(entry.sizeBytes)
            } else {
                missingSizes[key, default: []].insert(entry.sizeBytes)
            }
        }
    }

    public var isEmpty: Bool { sizes.isEmpty && missingSizes.isEmpty }

    /// True when the game is in the library and its file is on this device.
    public func contains(_ item: RemoteLibraryItem) -> Bool {
        Self.matches(item, in: sizes)
    }

    /// True when the library lists the game but has no file for it here, so a copy
    /// from the peer would make it playable.
    public func isMissingFile(_ item: RemoteLibraryItem) -> Bool {
        !contains(item) && Self.matches(item, in: missingSizes)
    }

    private static func matches(_ item: RemoteLibraryItem, in sizes: [Key: Set<Int64>]) -> Bool {
        guard let system = item.systemIdentifier, let md5 = item.md5, !md5.isEmpty,
              let localSizes = sizes[Key(system: system, md5: md5.uppercased())] else {
            return false
        }
        guard item.sizeBytes > 0 else { return true }
        return localSizes.contains { $0 <= 0 || $0 == item.sizeBytes }
    }
}
