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

/// Filters the authenticated find route without fetching a pull manifest.
struct LibraryLookup {
    let system: String
    let md5: String?
    let names: Set<String>

    init(_ query: MissingGameQuery) {
        system = query.system.rawValue
        md5 = query.isSingleFileImage ? query.md5.lowercased() : nil
        names = Set([query.title, query.primaryFile?.name ?? ""].map(MissingGameMatcher.normalised)).subtracting([""])
    }

    init?(_ query: [String: String]) {
        guard let system = query["system"], !system.isEmpty, system.count <= 120 else { return nil }
        let md5 = query["md5"]?.lowercased()
        if let md5, md5.count != 32 || !md5.allSatisfy(\.isHexDigit) { return nil }
        let names = query["names"] ?? ""
        guard names.count <= 1025, md5 != nil || !names.isEmpty else { return nil }
        self.system = system
        self.md5 = md5
        self.names = Set(names.split(separator: ",").map(String.init))
    }

    var items: [URLQueryItem] {
        var items = [URLQueryItem(name: "system", value: system)]
        if let md5, md5.count == 32, md5.allSatisfy(\.isHexDigit) {
            items.append(URLQueryItem(name: "md5", value: md5))
        }
        if !names.isEmpty {
            items.append(URLQueryItem(name: "names", value: names.sorted().map { String($0.prefix(512)) }.joined(separator: ",")))
        }
        return items
    }

    func admits(_ game: SharedGame) -> Bool {
        guard game.system.rawValue == system else { return false }
        if let md5, game.md5?.lowercased() == md5 { return true }
        return names.contains(MissingGameMatcher.normalised(game.title))
    }
}
