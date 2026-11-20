//
//  MissingGameQuery.swift
//  PVLibrarySharing
//
//  A library game whose files are gone, described for a search on other libraries.
//

import Foundation
import PVSystems

/// One file the game expects on disk.
public struct MissingGameFile: Sendable, Equatable, Codable {
    /// The file's name as the library records it (last path component).
    public var name: String
    /// Bytes, or 0 when the library never recorded a size.
    public var size: Int64
    public var isPrimary: Bool

    public init(name: String, size: Int64, isPrimary: Bool) {
        self.name = name
        self.size = size
        self.isPrimary = isPrimary
    }
}

public struct MissingGameQuery: Sendable, Equatable {
    /// The library's MD5 for the game. It equals a remote MD5 only for single-file,
    /// headerless images (see `LocalLibraryIndex`).
    public var md5: String
    public var system: SystemIdentifier
    public var title: String
    /// Every file of the game, the primary first.
    public var files: [MissingGameFile]
    public var isSingleFileImage: Bool

    public init(md5: String, system: SystemIdentifier, title: String, files: [MissingGameFile], isSingleFileImage: Bool) {
        self.md5 = md5
        self.system = system
        self.title = title
        self.files = files
        self.isSingleFileImage = isSingleFileImage
    }

    public var primaryFile: MissingGameFile? { files.first(where: \.isPrimary) ?? files.first }
}

/// How sure a match is.
public enum RecoveryMatchKind: Sendable, Equatable {
    /// The same game: same hash, the remembered item, or every file equal by name and size.
    case exact
    /// The same name but possibly another version. Fills the hole only after the user agrees.
    case standIn
}
