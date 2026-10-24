//
//  LibraryPuller.swift
//  PVLibrarySharing
//
//  Copies one game from a peer into staging (spec §3.5).
//

import Foundation
import PVSystems

/// What a copy is doing, for the progress row.
public enum LibraryPullProgress: Sendable, Equatable {
    /// Connecting, authenticating, or waiting for the host owner's approval.
    case preparing(LibraryBrowseProgress)
    case downloading(file: String, fileIndex: Int, fileCount: Int, bytesDone: Int64, totalBytes: Int64)
    /// Checking a finished file's SHA-256.
    case verifying(file: String)
}

/// A finished copy: verified game files in staging, ready for the importer.
public struct PulledGame: Sendable, Equatable {
    /// The copy's staging folder; `LibraryStaging.markHandedOff` takes it.
    public var folder: URL
    /// Every game file, the primary included, in the peer's order.
    public var gameFiles: [URL]
    /// The set's index (m3u/cue/gdi/ccd) when there is one, else the first file.
    public var primaryFile: URL
    /// The mapped system, passed to the importer so ambiguous extensions
    /// (`.chd`, `.iso`, `.bin`) don't prompt.
    public var systemIdentifier: SystemIdentifier?
    /// Kinds the peer offered that were left behind (BIOS, saves), for the log.
    public var skippedKinds: [String]
}

/// Downloads one item's game files with resume and SHA-256 checks.
///
/// - The pull manifest is cached in the staging folder. iFly's pull is metered
///   and may prompt the host owner per game, so a resumed copy (after a
///   dropped connection or a relaunch) reuses it and fetches only files. The
///   host's file allowlist outlives the token, so a fresh auth is enough. Only
///   a 404 on the file route ("not part of a granted pull", host restarted)
///   re-requests the manifest, once.
/// - Small files first, so a dead connection leaves the most usable set.
/// - Each file downloads into `<file>.part` with `Range: bytes=N-`. A 200 to a
///   ranged request restarts at zero, as does a 206 for the wrong range or a
///   416. The `.part` is renamed into place only after its SHA-256 matches;
///   on a mismatch it is deleted and the copy fails.
public struct LibraryPuller: Sendable {
    /// Restarts from zero allowed per file (416, wrong range) before giving up.
    static let maxRestartsPerFile = 2

    public let staging: LibraryStaging
    /// Distinguishes peers in staging folder names (`DiscoveredPeer.id`).
    public let peerKey: String

    public init(staging: LibraryStaging, peerKey: String) {
        self.staging = staging
        self.peerKey = peerKey
    }

    public func folder(for item: RemoteLibraryItem, from app: PeerApp) -> URL {
        staging.folder(peerKey: peerKey, app: app, itemId: item.id)
    }

    public func pull(
        _ item: RemoteLibraryItem,
        from source: any LibrarySource,
        manifest freshManifest: RemoteManifest? = nil,
        progress: @escaping @Sendable (LibraryPullProgress) -> Void
    ) async throws -> PulledGame {
        try Task.checkCancellation()
        let folder = folder(for: item, from: source.app)
        guard LibraryStaging.hasConfinedBase(folder) else { throw LibrarySharingError.unsafePath(folder.lastPathComponent) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard LibraryStaging.hasConfinedBase(folder) else { throw LibrarySharingError.unsafePath(folder.lastPathComponent) }
        if let freshManifest {
            guard freshManifest.itemId == item.id else { throw LibrarySharingError.itemUnavailable }
            if let old = Self.cachedManifest(in: folder), old != freshManifest {
                for file in old.gameFiles where !freshManifest.gameFiles.contains(file) {
                    if let partial = LibraryStaging.containedURL(for: file.relativePath + ".part", in: folder) {
                        try? FileManager.default.removeItem(at: partial)
                    }
                }
            }
            try Self.cache(freshManifest, in: folder)
        }
        do {
            return try await pull(item, from: source, folder: folder, progress: progress)
        } catch LibrarySharingError.fileUnavailable where Self.cachedManifest(in: folder) != nil {
            // The host forgot the grant (restart, token family cleared). Ask again once.
            Self.dropCachedManifest(in: folder)
            return try await pull(item, from: source, folder: folder, progress: progress)
        }
    }

    // MARK: - Private

    private func pull(
        _ item: RemoteLibraryItem,
        from source: any LibrarySource,
        folder: URL,
        progress: @escaping @Sendable (LibraryPullProgress) -> Void
    ) async throws -> PulledGame {
        let manifest: RemoteManifest
        if let cached = Self.cachedManifest(in: folder), cached.itemId == item.id {
            manifest = cached
        } else {
            manifest = try await source.pullManifest(for: item) { progress(.preparing($0)) }
            try Task.checkCancellation()
            try Self.cache(manifest, in: folder)
        }

        let games = manifest.gameFiles
        guard !games.isEmpty, let primary = manifest.primaryGameFile else { throw LibrarySharingError.nothingToCopy }
        var destinations: [String: URL] = [:]
        for file in games {
            guard let url = LibraryStaging.containedURL(for: file.relativePath, in: folder),
                  LibraryStaging.containedURL(for: file.relativePath + ".part", in: folder) != nil else {
                throw LibrarySharingError.unsafePath(file.relativePath)
            }
            destinations[file.relativePath] = url
        }

        let ordered = games.sorted { ($0.size, $0.relativePath) < ($1.size, $1.relativePath) }
        let totalBytes = manifest.gameBytes
        var bytesBefore: Int64 = 0
        for (index, file) in ordered.enumerated() {
            try Task.checkCancellation()
            guard let destination = destinations[file.relativePath] else { continue }
            let completed = bytesBefore
            try await fetch(file, of: manifest, from: source, to: destination) { event in
                switch event {
                case .bytesOnDisk(let onDisk):
                    progress(.downloading(
                        file: file.fileName, fileIndex: index, fileCount: ordered.count,
                        bytesDone: completed + onDisk, totalBytes: totalBytes
                    ))
                case .verifying:
                    progress(.verifying(file: file.fileName))
                }
            }
            bytesBefore += file.size
        }

        try Task.checkCancellation()
        return PulledGame(
            folder: folder,
            gameFiles: games.compactMap { destinations[$0.relativePath] },
            primaryFile: destinations[primary.relativePath] ?? folder,
            systemIdentifier: item.systemIdentifier,
            skippedKinds: Array(Set(manifest.skippedFiles.map(\.kind))).sorted()
        )
    }

    private enum FileEvent: Sendable {
        case bytesOnDisk(Int64)
        case verifying
    }

    /// One file: skip when already verified, else download (resuming) and verify.
    private func fetch(
        _ file: RemoteFile,
        of manifest: RemoteManifest,
        from source: any LibrarySource,
        to destination: URL,
        events: @escaping @Sendable (FileEvent) -> Void
    ) async throws {
        let manager = FileManager.default
        // A file in place was renamed there only after its hash matched.
        if Self.size(of: destination) == file.size,
           (try? FileSHA256.hex(of: destination).lowercased()) == file.sha256.lowercased() {
            events(.bytesOnDisk(file.size))
            return
        }
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let partial = destination.appendingPathExtension(LibraryStaging.partialExtension)

        var restarts = 0
        while true {
            try Task.checkCancellation()
            var offset = Self.size(of: partial) ?? 0
            if offset > file.size {
                try? manager.removeItem(at: partial)
                offset = 0
            }
            if offset == file.size, file.size > 0 {
                break // fully downloaded earlier; only the check is left
            }
            let response = try await source.download(
                file, of: manifest, to: partial, resumeOffset: offset
            ) { events(.bytesOnDisk($0)) }
            try Task.checkCancellation()
            if response.status == 416 || response.writtenFrom == nil {
                // Unsatisfiable or wrong range: start this file over.
                try? manager.removeItem(at: partial)
                restarts += 1
                guard restarts <= Self.maxRestartsPerFile else {
                    throw LibrarySharingError.invalidResponse(status: response.status)
                }
                continue
            }
            if response.bytesOnDisk >= file.size { break }
            // Short body (connection closed early): resume from what arrived.
            restarts += 1
            guard restarts <= Self.maxRestartsPerFile else { throw LibrarySharingError.unreachable }
        }

        events(.verifying)
        let actual = try FileSHA256.hex(of: partial)
        try Task.checkCancellation()
        guard actual.caseInsensitiveCompare(file.sha256) == .orderedSame, Self.size(of: partial) == file.size else {
            try? manager.removeItem(at: partial)
            throw LibrarySharingError.checksumMismatch(file.fileName)
        }
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.moveItem(at: partial, to: destination)
    }

    private static func size(of url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return (attributes[.size] as? NSNumber)?.int64Value
    }

    // MARK: - Manifest cache

    static func cachedManifest(in folder: URL) -> RemoteManifest? {
        let url = folder.appendingPathComponent(LibraryStaging.manifestName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RemoteManifest.self, from: data)
    }

    static func cache(_ manifest: RemoteManifest, in folder: URL) throws {
        let url = folder.appendingPathComponent(LibraryStaging.manifestName)
        try JSONEncoder().encode(manifest).write(to: url, options: .atomic)
    }

    static func dropCachedManifest(in folder: URL) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(LibraryStaging.manifestName))
    }
}
