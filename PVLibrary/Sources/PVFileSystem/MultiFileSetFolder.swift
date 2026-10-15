//
//  MultiFileSetFolder.swift
//  PVFileSystem
//
//  A game made of several files (a .gdi or .cue with its tracks, an .m3u with its
//  discs) imports into its own folder under the system's ROM folder, named after
//  the index file: `ROMs/<system>/<index stem>/`. Two sets whose tracks share
//  generic names (`track01.bin`) then never collide. Single-file games stay flat.
//
//  Pure naming and path rules, Foundation only.
//

import Foundation

public enum MultiFileSetFolder {

    /// Index files: they list the other files of a game.
    public static let indexExtensions: Set<String> = ["cue", "gdi", "m3u"]

    /// Name used when an index file's stem sanitises to nothing.
    public static let fallbackName = "Disc Set"

    /// Longest folder name in UTF-8 bytes, leaving room for a `-NN` suffix under the 255-byte limit.
    public static let maximumNameBytes = 240

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

    /// A folder name for an index file that is free in a system folder: the base name,
    /// else `base-2`, `base-3`, … `taken` holds every name already in the system folder
    /// (files and folders), compared case-insensitively. `canReuse` may claim a taken
    /// name whose folder already holds this same set (a repeated import).
    public static func folderName(
        forIndexFile fileName: String,
        taken: Set<String>,
        canReuse: (String) -> Bool = { _ in false }
    ) -> String {
        let base = baseName(forIndexFile: fileName)
        let lowercasedTaken = Set(taken.map { $0.lowercased() })
        var candidate = base
        var suffix = 1
        while lowercasedTaken.contains(candidate.lowercased()) {
            if canReuse(candidate) { return candidate }
            suffix += 1
            candidate = "\(base)-\(suffix)"
        }
        return candidate
    }

    /// True when `folderName` is the name `folderName(forIndexFile:)` gives `indexFileName`
    /// (its base name, or the base name with a `-N` suffix).
    public static func isSetFolder(named folderName: String, forIndexFile indexFileName: String) -> Bool {
        guard isIndexFile(indexFileName) else { return false }
        let base = baseName(forIndexFile: indexFileName).lowercased()
        let folder = folderName.lowercased()
        if folder == base { return true }
        guard folder.hasPrefix(base + "-") else { return false }
        let digits = folder.dropFirst(base.count + 1)
        return !digits.isEmpty && digits.allSatisfy { $0.isASCII && $0.isNumber }
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
