//
//  MultiFileSetIdentity.swift
//  PVLibrary
//
//  The identity (`PVGame.md5Hash`) of a game imported from a cue, gdi or m3u.
//
//  `md5Hash` is the game's Realm primary key, the import duplicate check, the CloudKit
//  ROM record id and the OpenVGDB lookup key. A single-file game's is the MD5 of the
//  file. A set's used to be the MD5 of its index text, and different games share that
//  byte for byte (most GD-ROM dumps have the same track table), so the second game was
//  refused as a duplicate. For games imported from now on, a set's identity is:
//
//  - cue: the MD5 of the first FILE that holds a data track (MODE1, MODE2 or CDI);
//  - gdi: the MD5 of the last data track (type 4), the high-density area with the
//    game's IP.BIN (the track `GdiDiscSerialPlugin` reads). Track 1, the low-density
//    area, is not unique: in the bundled ShiraGame redump data 8 Track 1 hashes are
//    shared by different Dreamcast games or releases, against none of 1147 Track 3s;
//  - m3u: the MD5 of `playlistKey(firstDiscMD5:)`, derived from its first disc's
//    identity, so the playlist game and a stand-alone import of disc 1 stay two rows
//    as they always were.
//
//  The whole track is hashed: that is what redump-derived databases (libretrodb,
//  ShiraGame) store per track, and single-file disc images (iso, chd) were already
//  hashed whole. When the identity file can't be found the index MD5 is used, as before.
//  OpenVGDB keys CD games by redump cue text instead, so a set no longer matches it
//  by MD5; libretrodb's track rows, serial and title lookups cover those systems.
//
//  Games already in the library keep their md5Hash: save states, CloudKit records and
//  per-game settings hang off it. The duplicate check therefore also looks for the
//  incoming set's index MD5, and takes such a legacy match as the same game unless the
//  existing game's own identity track shows it is a different one (`isSameGame`).
//
//  Foundation only; the importer does the hashing.
//

import Foundation

public enum MultiFileSetIdentity {

    /// The file whose MD5 makes a set's identity.
    public struct Source: Equatable, Sendable {
        public let file: URL
        /// Reached through an m3u playlist: the identity is the MD5 of `playlistKey(firstDiscMD5:)`.
        public let viaPlaylist: Bool

        public init(file: URL, viaPlaylist: Bool) {
            self.file = file
            self.viaPlaylist = viaPlaylist
        }
    }

    /// The identity source of the index file at `indexURL`. nil when it is not a cue, gdi or m3u,
    /// or names no data track or disc that can be found; the caller then uses the index file's MD5.
    public static func source(forIndexAt indexURL: URL, fileManager: FileManager = .default) -> Source? {
        guard let kind = MultiFileIndexKind(fileName: indexURL.lastPathComponent),
              let file = identityFile(of: kind, at: indexURL, fileManager: fileManager) else { return nil }
        guard kind == .m3u else { return Source(file: file, viaPlaylist: false) }
        // A playlist's first disc is an image or a cue/gdi set. Never follow a second playlist.
        switch MultiFileIndexKind(fileName: file.lastPathComponent) {
        case .m3u?:
            return nil
        case let discKind?:
            guard let track = identityFile(of: discKind, at: file, fileManager: fileManager) else { return nil }
            return Source(file: track, viaPlaylist: true)
        case nil:
            return Source(file: file, viaPlaylist: true)
        }
    }

    /// The text whose MD5 is a playlist game's identity, from its first disc's identity MD5.
    public static func playlistKey(firstDiscMD5: String) -> String {
        "m3u:" + firstDiscMD5.uppercased()
    }

    // MARK: Duplicate check

    /// How the duplicate check found an existing game for an incoming set.
    public enum Match: Equatable, Sendable {
        /// Its md5Hash is the incoming set's identity.
        case identity
        /// Its md5Hash is the incoming set's index-file MD5: it was imported before this rule.
        case legacyIndex
    }

    /// An identity file and its size, when known.
    public struct Fingerprint: Equatable, Sendable {
        public let file: URL
        public let size: Int64?

        public init(file: URL, size: Int64?) {
            self.file = file
            self.size = size
        }
    }

    /// Whether the existing game the duplicate check found is the incoming game.
    ///
    /// An identity match is. A legacy match is decided by the existing game's own identity
    /// file: a different size or identity MD5 means a different game whose index file is
    /// byte-identical. When that file can't be read (`existing` nil: not downloaded, moved,
    /// a track missing) the legacy match stands, as it did before. `existingMD5` is only
    /// called when the sizes don't already tell the two apart.
    public static func isSameGame(
        match: Match,
        existing: Fingerprint?,
        incoming: Fingerprint,
        incomingMD5: String,
        existingMD5: () async -> String?
    ) async -> Bool {
        guard match == .legacyIndex, let existing else { return true }
        if existing.file.standardizedFileURL == incoming.file.standardizedFileURL { return true }
        if let existingSize = existing.size, let incomingSize = incoming.size, existingSize != incomingSize {
            return false
        }
        guard let md5 = await existingMD5() else { return true }
        return md5.caseInsensitiveCompare(incomingMD5) == .orderedSame
    }

    // MARK: Resolving

    static func identityFile(of kind: MultiFileIndexKind, at indexURL: URL, fileManager: FileManager) -> URL? {
        guard let contents = try? MultiFileIndexReferences.readText(at: indexURL),
              let reference = MultiFileIndexReferences.identityReference(of: kind, contents: contents) else { return nil }
        return resolve(reference, nextTo: indexURL, fileManager: fileManager)
    }

    /// `reference` relative to the index file's folder, then by its last component in that
    /// folder (a set's files sit together), matching case-insensitively as the cores do.
    static func resolve(_ reference: String, nextTo indexURL: URL, fileManager: FileManager) -> URL? {
        let directory = indexURL.deletingLastPathComponent()
        let relative = reference.replacingOccurrences(of: "\\", with: "/")
        let leaf = (relative as NSString).lastPathComponent
        guard !leaf.isEmpty else { return nil }
        for candidate in [directory.appendingPathComponent(relative), directory.appendingPathComponent(leaf)]
        where isFile(candidate, fileManager: fileManager) {
            return candidate
        }
        guard let match = try? fileManager.contentsOfDirectory(atPath: directory.path)
            .first(where: { $0.caseInsensitiveCompare(leaf) == .orderedSame }) else { return nil }
        let url = directory.appendingPathComponent(match)
        return isFile(url, fileManager: fileManager) ? url : nil
    }

    private static func isFile(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }
}
