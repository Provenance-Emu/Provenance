//
//  MultiFileSetFolder.swift
//  PVFileSystem
//
//  A game made of several files (a .gdi or .cue with its tracks, an .m3u with its
//  discs) imports into its own folder under the system's ROM folder, named after
//  the index file: `ROMs/<system>/<index stem>/`. Two sets whose tracks share
//  generic names (`track01.bin`) then never collide. Single-file games stay flat.
//  When another set has the name, the folder is `<index stem>-<first 8 of the
//  game's md5Hash>`, so every device names it the same; folders created before
//  that (`<index stem>-2`, `-3`, … in import order) keep their names.
//
//  Pure naming and path rules, Foundation only.
//

import Foundation

public enum MultiFileSetFolder {

    /// Index files: they list the other files of a game.
    public static let indexExtensions: Set<String> = ["cue", "gdi", "m3u"]

    /// Name used when an index file's stem sanitises to nothing.
    public static let fallbackName = "Disc Set"

    /// Longest folder name in UTF-8 bytes, leaving room for a `-XXXXXXXX` suffix under the 255-byte limit.
    public static let maximumNameBytes = 240

    /// Hex digits of the game's md5Hash that tell two sets with the same index name apart.
    public static let identitySuffixLength = 8

    /// Name of the folder that holds the ROM tree.
    static let romsDirectoryName = "ROMs"

    public static func isIndexFile(_ fileName: String) -> Bool {
        indexExtensions.contains((fileName as NSString).pathExtension.lowercased())
    }

    // MARK: Naming

    /// The folder name an index file asks for: its stem, made safe for a folder name.
    /// Path separators and control characters go, leading dots go (a hidden folder is
    /// never scanned), trailing spaces and dots go, and the result is capped in length.
    public static func baseName(forIndexFile fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        var scalars = String.UnicodeScalarView()
        for scalar in stem.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) { continue }
            switch scalar {
            case "/", "\\", ":":
                scalars.append("_")
            default:
                scalars.append(scalar)
            }
        }
        var name = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") {
            name = String(name.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        name = trimmingTrailingDotsAndSpaces(name)
        if name.utf8.count > maximumNameBytes {
            var capped = ""
            for character in name {
                guard capped.utf8.count + String(character).utf8.count <= maximumNameBytes else { break }
                capped.append(character)
            }
            name = trimmingTrailingDotsAndSpaces(capped)
        }
        return name.isEmpty ? fallbackName : name
    }

    /// A folder name for an index file that is free in a system folder. `taken` holds every
    /// name already in the system folder (files and folders), compared case-insensitively.
    ///
    /// - The base name when it is free.
    /// - Else a taken set-folder name for this index (the base name, `base-<hex>` or a legacy
    ///   `base-N`) that `canReuse` claims: its folder already holds this same set (a repeated import).
    /// - Else `base-<first 8 of identityMD5>`, the same on every device that imports the set.
    /// - Else (no identity, or that name taken too) the first free `base-2`, `base-3`, …
    public static func folderName(
        forIndexFile fileName: String,
        taken: Set<String>,
        identityMD5: String? = nil,
        canReuse: (String) -> Bool = { _ in false }
    ) -> String {
        let base = baseName(forIndexFile: fileName)
        let lowercasedTaken = Set(taken.map { $0.lowercased() })
        guard lowercasedTaken.contains(base.lowercased()) else { return base }

        let existingSetFolders = taken
            .filter { isSetFolder(named: $0, forIndexFile: fileName) }
            .sorted { lhs, rhs in
                let lhsIsBase = lhs.lowercased() == base.lowercased()
                let rhsIsBase = rhs.lowercased() == base.lowercased()
                if lhsIsBase != rhsIsBase { return lhsIsBase }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        if let reused = existingSetFolders.first(where: canReuse) {
            return reused
        }

        if let suffix = identitySuffix(forMD5: identityMD5) {
            let candidate = "\(base)-\(suffix)"
            if !lowercasedTaken.contains(candidate.lowercased()) {
                return candidate
            }
        }

        var suffix = 2
        while lowercasedTaken.contains("\(base)-\(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }

    /// The first `identitySuffixLength` hex digits of `md5`, uppercased like `PVGame.md5Hash`.
    /// Nil when `md5` is missing, too short or not hex.
    public static func identitySuffix(forMD5 md5: String?) -> String? {
        guard let md5 else { return nil }
        let prefix = String(md5.prefix(identitySuffixLength)).uppercased()
        guard prefix.count == identitySuffixLength, prefix.allSatisfy(\.isHexDigit) else { return nil }
        return prefix
    }

    /// True when `folderName` is a name `folderName(forIndexFile:)` gives `indexFileName`: its
    /// base name, the base name with an identity suffix (`-` and 8 hex digits), or with a
    /// legacy `-N` suffix.
    public static func isSetFolder(named folderName: String, forIndexFile indexFileName: String) -> Bool {
        guard isIndexFile(indexFileName) else { return false }
        let base = baseName(forIndexFile: indexFileName).lowercased()
        let folder = folderName.lowercased()
        if folder == base { return true }
        guard folder.hasPrefix(base + "-") else { return false }
        let suffix = folder.dropFirst(base.count + 1)
        guard !suffix.isEmpty, suffix.allSatisfy(\.isASCII) else { return false }
        if suffix.allSatisfy(\.isNumber) { return true }
        return suffix.count == identitySuffixLength && suffix.allSatisfy(\.isHexDigit)
    }

    // MARK: Locations

    /// Where a file sits under `ROMs/`.
    public struct ROMLocation: Equatable, Sendable {
        /// The system folder, e.g. `com.provenance.dreamcast`.
        public let systemIdentifier: String
        /// The path below the system folder: `game.gdi` or `game/game.gdi`.
        public let relativePath: String
        /// The set folder the file is in, nil for a file directly in the system folder.
        public let setFolder: String?

        public init(systemIdentifier: String, relativePath: String, setFolder: String?) {
            self.systemIdentifier = systemIdentifier
            self.relativePath = relativePath
            self.setFolder = setFolder
        }

        /// `systemIdentifier/relativePath`, the shape of `PVGame.romPath`.
        public var romPath: String { "\(systemIdentifier)/\(relativePath)" }
    }

    /// The location of `url` under the last `ROMs` folder in its path, when it is a file
    /// directly in a system folder or one folder below it. Nil otherwise.
    public static func romLocation(of url: URL) -> ROMLocation? {
        let components = url.standardizedFileURL.pathComponents
        guard let romsIndex = components.lastIndex(of: romsDirectoryName) else { return nil }
        let below = Array(components[(romsIndex + 1)...])
        guard below.count == 2 || below.count == 3, below.allSatisfy({ !$0.isEmpty && $0 != "/" }) else { return nil }
        let relative = Array(below.dropFirst())
        return ROMLocation(
            systemIdentifier: below[0],
            relativePath: relative.joined(separator: "/"),
            setFolder: relative.count == 2 ? relative[0] : nil
        )
    }

    /// The system folder a library file sits in: its parent, or for a file in a set folder
    /// (`ROMs/<system>/<set>/<file>`), the folder above that.
    public static func systemFolderName(ofFileAt url: URL) -> String {
        if let location = romLocation(of: url), location.setFolder != nil {
            return location.systemIdentifier
        }
        return url.deletingLastPathComponent().lastPathComponent
    }

    /// The set folder an index file sits in, when it sits in one of its own
    /// (`ROMs/<system>/<folder>/<index>`, with `folder` named after the index file).
    public static func setFolder(ofIndexFileAt url: URL) -> String? {
        guard let location = romLocation(of: url), let folder = location.setFolder,
              isSetFolder(named: folder, forIndexFile: url.lastPathComponent) else { return nil }
        return folder
    }

    /// The name save states, battery saves and cheats are filed under for a ROM: its
    /// stem, except for an index file in a de-duplicated set folder (`disc-2/disc.gdi`),
    /// which uses the folder name so two sets with the same index name don't share saves.
    public static func saveName(forROMAt url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        guard let folder = setFolder(ofIndexFileAt: url),
              folder.lowercased() != baseName(forIndexFile: url.lastPathComponent).lowercased() else {
            return stem
        }
        return folder
    }

    private static func trimmingTrailingDotsAndSpaces(_ name: String) -> String {
        var result = name
        while let last = result.last, last == "." || last.isWhitespace {
            result.removeLast()
        }
        return result
    }
}
