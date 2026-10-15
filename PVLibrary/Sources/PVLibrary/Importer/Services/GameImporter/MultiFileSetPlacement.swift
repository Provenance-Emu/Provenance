//
//  MultiFileSetPlacement.swift
//  PVLibrary
//
//  File-system side of `MultiFileSetFolder`: which files belong to a set, moving a
//  set into its own folder under the system's ROM folder, finding the games inside
//  set folders on a rescan, and removing a set folder once its game is deleted.
//  Foundation only, so it can be tested on a temporary folder.
//

import Foundation
import PVFileSystem

public enum MultiFileSetPlacement {

    public struct Placement: Equatable, Sendable {
        /// The set's folder, `ROMs/<system>/<name>/`.
        public let folder: URL
        /// The index file in its new place.
        public let index: URL
        /// The set's other files in their new place, in the order given.
        public let members: [URL]
        /// The folder already held this same set (a repeated import): the copies already there were kept.
        public let reusedExistingFolder: Bool
    }

    // MARK: Membership

    /// Every file name an index lists, following discs that are index files themselves
    /// (an m3u's cue sheets). A nested index is read from `candidates` when it is there,
    /// otherwise from beside the outer index.
    public static func referencedNames(ofIndexAt indexURL: URL, candidates: [URL] = []) -> [String] {
        let candidatesByName = Dictionary(candidates.map { ($0.lastPathComponent.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let directory = indexURL.deletingLastPathComponent()
        var names: [String] = []
        var seen: Set<String> = [indexURL.lastPathComponent.lowercased()]
        var pending = [indexURL]
        while !pending.isEmpty {
            let current = pending.removeFirst()
            for name in directReferences(ofIndexAt: current) where seen.insert(name.lowercased()).inserted {
                names.append(name)
                if MultiFileIndexKind(fileName: name) != nil {
                    pending.append(candidatesByName[name.lowercased()] ?? directory.appendingPathComponent(name))
                }
            }
        }
        return names
    }

    /// The candidates that belong to the index's set, in candidate order: the files it lists,
    /// plus files named like the index or one of those (a cue's `.sbi`, which Mednafen loads
    /// from beside the cue). Other guesses (a similar name) are left out, so they never land
    /// in another game's folder.
    public static func members(ofIndexAt indexURL: URL, among candidates: [URL]) -> [URL] {
        let listed = referencedNames(ofIndexAt: indexURL, candidates: candidates)
        let names = Set(listed.map { $0.lowercased() })
        let stems = Set(([indexURL.lastPathComponent] + listed).map { stem(of: $0) })
        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.lastPathComponent.lowercased()
            guard candidate.standardizedFileURL != indexURL.standardizedFileURL,
                  names.contains(key) || stems.contains(stem(of: key)) else { return false }
            return seen.insert(key).inserted
        }
    }

    /// True for an index file that lists at least one file: it gets a folder of its own.
    public static func isMultiFileSet(indexAt url: URL) -> Bool {
        MultiFileSetFolder.isIndexFile(url.lastPathComponent) && !directReferences(ofIndexAt: url).isEmpty
    }

    // MARK: Placement

    /// The folder a set goes into (`MultiFileSetFolder.folderName`): a set folder that already holds
    /// this same set, else `<index stem>-<first 8 of identityMD5>`. `identityMD5` is the game's
    /// md5Hash; without it the bare stem, then `-N`.
    public static func folder(
        forIndexAt indexURL: URL,
        members: [URL],
        in systemDirectory: URL,
        identityMD5: String? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let taken = takenNames(in: systemDirectory, fileManager: fileManager)
        let name = MultiFileSetFolder.folderName(forIndexFile: indexURL.lastPathComponent, taken: taken, identityMD5: identityMD5) { candidate in
            holdsSameSet(systemDirectory.appendingPathComponent(candidate, isDirectory: true),
                         index: indexURL, members: members, fileManager: fileManager)
        }
        return systemDirectory.appendingPathComponent(name, isDirectory: true)
    }

    /// Moves the index and its members into their folder under `systemDirectory`.
    /// When the folder already holds this same set, the incoming copies are removed instead.
    public static func place(
        indexAt indexURL: URL,
        members: [URL],
        in systemDirectory: URL,
        identityMD5: String? = nil,
        fileManager: FileManager = .default
    ) throws -> Placement {
        let folder = folder(forIndexAt: indexURL, members: members, in: systemDirectory, identityMD5: identityMD5, fileManager: fileManager)
        let reused = fileManager.fileExists(atPath: folder.path)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = try move(indexURL, into: folder, keepingExisting: reused, fileManager: fileManager)
        let movedMembers = try members.map { try move($0, into: folder, keepingExisting: reused, fileManager: fileManager) }
        return Placement(folder: folder, index: index, members: movedMembers, reusedExistingFolder: reused)
    }

    // MARK: Library scan

    /// The games in a system folder's set folders: in each folder named after an index file
    /// it holds, the outermost index files. Other folders (a DOS game, a NAOMI GD-ROM
    /// folder next to its zip) are skipped.
    public static func indexFilesInSetFolders(of systemDirectory: URL, fileManager: FileManager = .default) -> [URL] {
        subdirectories(of: systemDirectory, fileManager: fileManager)
            .filter { isSetFolder($0, fileManager: fileManager) }
            .flatMap { outermostIndexFiles(in: $0, fileManager: fileManager) }
    }

    /// Index files directly in `directory` that no other index file there lists (an m3u hides its discs).
    public static func outermostIndexFiles(in directory: URL, fileManager: FileManager = .default) -> [URL] {
        let indexes = files(in: directory, fileManager: fileManager)
            .filter { MultiFileSetFolder.isIndexFile($0.lastPathComponent) }
        let nested = Set(indexes.flatMap { directReferences(ofIndexAt: $0) }.map { $0.lowercased() })
        return indexes.filter { !nested.contains($0.lastPathComponent.lowercased()) }
    }

    /// A folder named after one of the index files directly inside it.
    public static func isSetFolder(_ directory: URL, fileManager: FileManager = .default) -> Bool {
        outermostIndexFiles(in: directory, fileManager: fileManager).contains {
            MultiFileSetFolder.isSetFolder(named: directory.lastPathComponent, forIndexFile: $0.lastPathComponent)
        }
    }

    // MARK: Deletion

    /// The set folder a game file is in: `ROMs/<system>/<folder>/` when that folder is named
    /// after an index file in it. Nil for a flat file or any other folder.
    public static func setFolder(ofGameFileAt url: URL, fileManager: FileManager = .default) -> URL? {
        guard MultiFileSetFolder.romLocation(of: url)?.setFolder != nil else { return nil }
        let folder = url.deletingLastPathComponent()
        return isSetFolder(folder, fileManager: fileManager) ? folder : nil
    }

    /// Removes a set folder, taken from `setFolder(ofGameFileAt:)` before the game's files were
    /// deleted, unless `isStillInUse` reports another game in it. `isStillInUse` gets the folder's
    /// `romPath` prefix (`<system>/<folder>/`).
    @discardableResult
    public static func removeSetFolderIfUnused(
        _ folder: URL,
        isStillInUse: (String) -> Bool,
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard let location = MultiFileSetFolder.romLocation(of: folder),
              location.setFolder == nil,
              fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue,
              !isStillInUse("\(location.romPath)/") else { return false }
        do {
            try fileManager.removeItem(at: folder)
            return true
        } catch {
            return false
        }
    }

    // MARK: Helpers

    private static func takenNames(in systemDirectory: URL, fileManager: FileManager) -> Set<String> {
        Set((try? fileManager.contentsOfDirectory(atPath: systemDirectory.path)) ?? [])
    }

    private static func stem(of fileName: String) -> String {
        (fileName as NSString).deletingPathExtension.lowercased()
    }

    private static func directReferences(ofIndexAt url: URL) -> [String] {
        guard let kind = MultiFileIndexKind(fileName: url.lastPathComponent),
              let text = try? MultiFileIndexReferences.readText(at: url) else { return [] }
        return MultiFileIndexReferences.referencedFiles(of: kind, contents: text)
    }

    /// The folder is empty (a set whose files were removed, e.g. evicted before a re-download),
    /// or holds the index (same bytes) and every member (same size).
    private static func holdsSameSet(_ folder: URL, index: URL, members: [URL], fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
        if entries(of: folder, fileManager: fileManager).isEmpty { return true }
        let existingIndex = folder.appendingPathComponent(index.lastPathComponent)
        guard fileManager.contentsEqual(atPath: index.path, andPath: existingIndex.path) else { return false }
        return members.allSatisfy { member in
            let existing = folder.appendingPathComponent(member.lastPathComponent)
            guard let size = fileSize(member, fileManager), let existingSize = fileSize(existing, fileManager) else { return false }
            return size == existingSize
        }
    }

    private static func move(_ file: URL, into folder: URL, keepingExisting: Bool, fileManager: FileManager) throws -> URL {
        let destination = folder.appendingPathComponent(file.lastPathComponent)
        guard file.standardizedFileURL != destination.standardizedFileURL else { return destination }
        if fileManager.fileExists(atPath: destination.path) {
            guard keepingExisting else { throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: destination.path]) }
            try fileManager.removeItem(at: file)
            return destination
        }
        try fileManager.moveItem(at: file, to: destination)
        return destination
    }

    private static func fileSize(_ url: URL, _ fileManager: FileManager) -> UInt64? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value
    }

    private static func subdirectories(of directory: URL, fileManager: FileManager) -> [URL] {
        entries(of: directory, fileManager: fileManager).filter { isDirectory($0) }
    }

    private static func files(in directory: URL, fileManager: FileManager) -> [URL] {
        entries(of: directory, fileManager: fileManager).filter { !isDirectory($0) }
    }

    private static func entries(of directory: URL, fileManager: FileManager) -> [URL] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return entries.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
