//
//  RemoteManifest.swift
//  PVLibrarySharing
//
//  What a peer says it will send for one game (spec §3.5).
//

import Foundation

/// One file a peer offers for a game.
public struct RemoteFile: Sendable, Hashable, Codable {
    /// The game image or one of its siblings (GDI tracks, a Naomi CHD).
    public static let gameFileKind = "gameFile"

    /// The peer's kind string, kept raw: iFly and iCube use `gameFile`, `bios`,
    /// `saveState`, `vmuPerGame`, `gameCubeMemoryCard` and more.
    public var kind: String
    /// Peer-relative path, sent back unchanged on the file route. Never trusted
    /// as a local path: `LibraryStaging.containedURL` checks it first.
    public var relativePath: String
    /// Lower-case hex SHA-256 of the whole file.
    public var sha256: String
    public var size: Int64
    /// Whether the peer considers the game unusable without this file.
    public var required: Bool

    public init(kind: String, relativePath: String, sha256: String, size: Int64, required: Bool = true) {
        self.kind = kind
        self.relativePath = relativePath
        self.sha256 = sha256.lowercased()
        self.size = size
        self.required = required
    }

    public var isGameFile: Bool { kind == Self.gameFileKind }
    public var fileName: String { (relativePath as NSString).lastPathComponent }
}

/// The files a peer offers for one game.
///
/// Provenance copies only game files. BIOS needs the user to confirm first
/// (spec §3.6) and is not copied yet; save states and memory cards come from a
/// different core and never load, so they are always skipped.
public struct RemoteManifest: Sendable, Hashable, Codable {
    /// The `RemoteLibraryItem.id` this manifest was fetched for.
    public var itemId: String
    public var files: [RemoteFile]

    public init(itemId: String, files: [RemoteFile]) {
        self.itemId = itemId
        self.files = files
    }

    public var gameFiles: [RemoteFile] { files.filter(\.isGameFile) }

    /// Files the peer offered that Provenance leaves behind (BIOS, saves).
    public var skippedFiles: [RemoteFile] { files.filter { !$0.isGameFile } }

    public var gameBytes: Int64 { gameFiles.reduce(0) { $0 + $1.size } }

    /// Index extensions that name a whole set, in order of preference: a
    /// playlist over a single disc's index.
    static let indexExtensions = ["m3u", "cue", "gdi", "ccd"]

    /// The file that stands for the game: a set's index when there is one,
    /// otherwise the first game file in the peer's order (iFly lists the
    /// primary before its siblings; iCube sends one file).
    public var primaryGameFile: RemoteFile? {
        let games = gameFiles
        for ext in Self.indexExtensions {
            if let index = games.first(where: { ($0.relativePath as NSString).pathExtension.lowercased() == ext }) {
                return index
            }
        }
        return games.first
    }
}
