//
//  MultiFileSetArrivals.swift
//  PVLibrary
//
//  iCloud Drive downloads a library one file at a time. A .cue, .gdi or .m3u that
//  arrives before its tracks (or tracks before their index) must not be imported
//  on its own, and a set must not wait for the whole library to finish downloading
//  either. This groups the files that have arrived, folder by folder:
//
//  - Each arrival re-runs grouping for its folder. An index whose listed files are
//    all downloaded is released with them (and a cue's .sbi), so a set imports as
//    soon as its last file lands, whichever file that is.
//  - A file that may belong to a set is held: one in a set folder
//    (`ROMs/<system>/<set>/`, `isInSetFolder`), in a folder with an index still
//    downloading or held, listed by an index already on disk, or with a disc-track
//    extension. Anything else is released alone at once.
//  - A file listed by an index whose game is already in the library is dropped, and
//    so are held files of such an index (`discardMembers(ofIndexAt:)`).
//  - Other folders under a system folder (a DOS game, an unpacked MAME set, a NAOMI
//    GD-ROM folder) are not set folders; the syncer ignores them as it always did.
//  - `flush()` releases everything still held, for when no download is pending
//    (a lone .bin game, a set missing a file).
//
//  The disk is the source of truth: a file is downloaded when it exists at its real
//  path (iCloud keeps a not-yet-downloaded file as a hidden `.name.icloud`).
//  Foundation only.
//

import Foundation
import PVFileSystem

public struct MultiFileSetArrivals {

    /// Extensions of files that are usually tracks of a disc set, held even before an index for them is known.
    static let trackExtensions: Set<String> = ["bin", "raw", "img", "wav", "sub", "sbi", "ccd", "mdf", "mds", "ecm"]

    /// Downloaded files not released yet, by folder path, in arrival order.
    private var held: [String: [URL]] = [:]

    public init() {}

    /// Number of files held back.
    public var heldCount: Int {
        held.values.reduce(0) { $0 + $1.count }
    }

    /// Records a downloaded file and returns what can be imported now: each batch is an index with
    /// its files, or a single file. Empty while the file waits for the rest of its set.
    ///
    /// - Parameters:
    ///   - pending: files known to the cloud but not downloaded yet.
    ///   - importedIndexes: index files on disk whose game is already in the library.
    public mutating func arrived(
        _ file: URL,
        pending: Set<URL>,
        importedIndexes: Set<URL> = [],
        fileManager: FileManager = .default
    ) -> [[URL]] {
        let folder = file.deletingLastPathComponent()
        let key = Self.key(of: folder)
        if !Self.isIndex(file) {
            let diskIndexes = MultiFileSetPlacement.outermostIndexFiles(in: folder, fileManager: fileManager)
            let listing = diskIndexes.filter { Self.lists($0, file) }
            if listing.contains(where: { index in importedIndexes.contains { Self.isSameFile($0, index) } }) {
                return []
            }
            let mayBelongToASet = !listing.isEmpty
                || held[key, default: []].contains(where: Self.isIndex)
                || pending.contains { Self.isIndex($0) && Self.key(of: $0.deletingLastPathComponent()) == key }
                || Self.isInSetFolder(file, pending: pending, fileManager: fileManager)
                || Self.trackExtensions.contains(file.pathExtension.lowercased())
            guard mayBelongToASet else { return [[file]] }
        }
        if !held[key, default: []].contains(where: { Self.isSameFile($0, file) }) {
            held[key, default: []].append(file)
        }
        return regroup(folder, fileManager: fileManager)
    }

    /// Drops held files that `index` lists, when its game is already in the library.
    public mutating func discardMembers(ofIndexAt index: URL) {
        let key = Self.key(of: index.deletingLastPathComponent())
        guard let files = held[key] else { return }
        let members = MultiFileSetPlacement.members(ofIndexAt: index, among: files) + [index]
        let remaining = files.filter { file in !members.contains { Self.isSameFile($0, file) } }
        held[key] = remaining.isEmpty ? nil : remaining
    }

    /// Whether `file` sits in a disc set's own folder: one level below a system folder, in a folder
    /// named after an index file there (downloaded, still pending, or `file` itself). A DOS game,
    /// unpacked MAME or NAOMI GD-ROM folder is not one.
    public static func isInSetFolder(_ file: URL, pending: Set<URL>, fileManager: FileManager = .default) -> Bool {
        guard let folderName = MultiFileSetFolder.romLocation(of: file)?.setFolder else { return false }
        let folder = file.deletingLastPathComponent()
        let folderKey = key(of: folder)
        let candidates = [file]
            + pending.filter { key(of: $0.deletingLastPathComponent()) == folderKey }
            + MultiFileSetPlacement.outermostIndexFiles(in: folder, fileManager: fileManager)
        return candidates.contains { MultiFileSetFolder.isSetFolder(named: folderName, forIndexFile: $0.lastPathComponent) }
    }

    /// Everything still held, one batch per folder, index files first.
    public mutating func flush() -> [[URL]] {
        let batches = held.keys.sorted().compactMap { key -> [URL]? in
            guard let files = held[key], !files.isEmpty else { return nil }
            return files.filter(Self.isIndex) + files.filter { !Self.isIndex($0) }
        }
        held.removeAll()
        return batches
    }

    // MARK: Grouping

    /// Releases every held index in `folder` whose listed files are all downloaded, with those files.
    private mutating func regroup(_ folder: URL, fileManager: FileManager) -> [[URL]] {
        let key = Self.key(of: folder)
        var batches: [[URL]] = []
        for index in (held[key] ?? []).filter(Self.isIndex) {
            let files = held[key] ?? []
            guard files.contains(where: { Self.isSameFile($0, index) }),
                  !isListedByAnotherIndex(index, among: files, fileManager: fileManager) else { continue }
            let names = MultiFileSetPlacement.referencedNames(ofIndexAt: index, candidates: files)
            let complete = names.allSatisfy { MultiFileSetIdentity.resolve($0, nextTo: index, fileManager: fileManager) != nil }
            guard complete else { continue }
            let members = MultiFileSetPlacement.members(ofIndexAt: index, among: files)
            let batch = [index] + members
            held[key] = files.filter { file in !batch.contains { Self.isSameFile($0, file) } }
            batches.append(batch)
        }
        if held[key]?.isEmpty == true {
            held[key] = nil
        }
        return batches
    }

    /// A disc of a playlist goes with the playlist: an index another index in the folder lists.
    private func isListedByAnotherIndex(_ index: URL, among files: [URL], fileManager: FileManager) -> Bool {
        let folder = index.deletingLastPathComponent()
        let others = (files.filter(Self.isIndex) + MultiFileSetPlacement.outermostIndexFiles(in: folder, fileManager: fileManager))
            .filter { !Self.isSameFile($0, index) }
        return others.contains { Self.lists($0, index) }
    }

    // MARK: Helpers

    static func isIndex(_ url: URL) -> Bool {
        MultiFileIndexKind(fileName: url.lastPathComponent) != nil
    }

    /// Whether `index` lists `file` (directly, or through a disc it lists).
    static func lists(_ index: URL, _ file: URL) -> Bool {
        MultiFileSetPlacement.referencedNames(ofIndexAt: index).contains {
            ($0.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
                .caseInsensitiveCompare(file.lastPathComponent) == .orderedSame
        }
    }

    private static func isSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    private static func key(of folder: URL) -> String {
        folder.standardizedFileURL.path
    }
}

/// `MultiFileSetArrivals` for the iCloud Drive ROM syncer, whose arrivals come in on concurrent
/// tasks, with the sets it released waiting to be imported one at a time.
actor MultiFileSetArrivalQueue {
    private var arrivals = MultiFileSetArrivals()
    private var ready: [[URL]] = []

    /// Records a downloaded file and returns the single files released by it; sets wait in `nextSet()`.
    func arrived(_ file: URL, pending: Set<URL>, importedIndexes: Set<URL>) -> [URL] {
        enqueue(arrivals.arrived(file, pending: pending, importedIndexes: importedIndexes))
    }

    /// Drops held files of a set whose game is already in the library.
    func discardMembers(ofIndexAt index: URL) {
        arrivals.discardMembers(ofIndexAt: index)
    }

    /// Releases everything held (no download is pending) and returns the single files among it.
    func flush() -> [URL] {
        enqueue(arrivals.flush())
    }

    /// The next set to import, if one is complete.
    func nextSet() -> [URL]? {
        ready.isEmpty ? nil : ready.removeFirst()
    }

    var hasReadySets: Bool { !ready.isEmpty }

    var heldCount: Int { arrivals.heldCount }

    /// Files held or released in sets and not handed to the importer yet.
    var count: Int { arrivals.heldCount + ready.reduce(0) { $0 + $1.count } }

    private func enqueue(_ batches: [[URL]]) -> [URL] {
        var singles: [URL] = []
        for batch in batches {
            if batch.count == 1 {
                singles.append(contentsOf: batch)
            } else {
                ready.append(batch)
            }
        }
        return singles
    }
}
