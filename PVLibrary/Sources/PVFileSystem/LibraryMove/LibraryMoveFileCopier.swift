//
//  LibraryMoveFileCopier.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Moves one planned file: copy, verify (size always; MD5 under ROMs/ and BIOS/), and the
//  conflict rule. Nothing is ever overwritten or deleted. A pre-existing destination file is
//  "identical" only when its size and MD5 match, in every folder. When it differs, the copy phase
//  moves it aside to Conflicts/ and puts the incoming file at the real path (`displaceExisting`);
//  the post-switch sweep, where the destination is live, files the incoming file under Conflicts/
//  instead (`fileIncoming`).
//  Every copy is written to a hidden temp file next to its target, verified, then renamed into place,
//  so the real path never holds a partial file.
//  The source is left in place; cleanup deletes it after the switch.
//

import Foundation
import PVHashing
import PVLogging

public struct LibraryMoveFileCopier: Sendable {
    /// What to do with a pre-existing destination file that differs from the incoming one.
    public enum ConflictPolicy: Sendable {
        /// Leave the destination file alone and put the incoming copy under `Conflicts/`.
        case fileIncoming
        /// Move the destination file aside to `Conflicts/` and put the incoming copy at the real path.
        case displaceExisting
    }

    /// Suffix of the hidden temp file a copy is written to before it is verified and renamed into place.
    static let partialSuffix = ".librarymove-partial"

    /// `<dir>/.<name>.librarymove-partial`. Dot-prefixed, so the planner (`.skipsHiddenFiles`) never plans it.
    static func partialURL(for target: URL) -> URL {
        target.deletingLastPathComponent().appendingPathComponent("." + target.lastPathComponent + partialSuffix)
    }

    private let fileManager: FileManager
    private let md5Provider: any MD5Provider

    public init(fileManager: FileManager = .default, md5Provider: any MD5Provider = FileManager.default) {
        self.fileManager = fileManager
        self.md5Provider = md5Provider
    }

    public static func needsMD5(_ relativePath: String) -> Bool {
        guard let top = relativePath.split(separator: "/", maxSplits: 1).first else { return false }
        return LibraryMoveFolders.md5Verified.contains(String(top))
    }

    /// Copies `item` from `sourceRoot` to `destinationRoot` and verifies the copy.
    /// - Parameter onConflict: what to do when the destination holds a different file at the path.
    /// - Returns: the journal entry, or `nil` when the source no longer exists (skipped, not an error).
    /// - Throws: `LibraryMoveError.verificationFailed` after one retry; file-system errors as thrown.
    public func transfer(_ item: LibraryMovePlan.Item, from sourceRoot: URL, to destinationRoot: URL,
                         onConflict: ConflictPolicy = .fileIncoming) throws -> LibraryMoveJournal.Entry? {
        guard let facts = try sourceFacts(of: item, under: sourceRoot) else { return nil }
        let destination = destinationRoot.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: destination.path) else {
            try copyVerified(from: facts.url, to: destination, size: facts.size, md5: facts.md5, relativePath: item.relativePath)
            return .init(size: facts.size, md5: facts.md5, modified: facts.modified, state: .copied, destinationPath: nil)
        }
        // A pre-existing destination file is "identical" only when its content hash matches, in every folder:
        // fixed-size files (SRAM saves, many save states) collide on size alone, and cleanup deletes the source of an
        // identical entry. The folder policy (`needsMD5`) only governs post-copy verification.
        if let sourceMD5 = facts.md5 ?? md5Provider.md5ForFile(at: facts.url, fromOffset: 0),
           verify(destination, expectedSize: facts.size, expectedMD5: sourceMD5) {
            return .init(size: facts.size, md5: facts.md5, modified: facts.modified, state: .identical, destinationPath: nil)
        }
        if onConflict == .displaceExisting, isRegularFile(destination) {
            return try copyDisplacingExisting(item, facts, destination: destination, destinationRoot: destinationRoot)
        }
        return try copyToConflicts(item, facts, destinationRoot: destinationRoot)
    }

    /// Like `transfer`, but for a source known to differ from what the destination holds (a file that changed after it
    /// was copied). The destination is never consulted: the source always goes to `Conflicts/`, even when a size-only
    /// check would call the two files identical.
    public func transferAsConflict(_ item: LibraryMovePlan.Item, from sourceRoot: URL, to destinationRoot: URL) throws -> LibraryMoveJournal.Entry? {
        guard let facts = try sourceFacts(of: item, under: sourceRoot) else { return nil }
        return try copyToConflicts(item, facts, destinationRoot: destinationRoot)
    }

    /// `true` when the file at `url` exists with `expectedSize` bytes and, when given, `expectedMD5`.
    public func verify(_ url: URL, expectedSize: Int64, expectedMD5: String?) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { return false }
        guard Int64(values.fileSize ?? -1) == expectedSize else { return false }
        guard let expectedMD5 else { return true }
        return md5Provider.md5ForFile(at: url, fromOffset: 0)?.lowercased() == expectedMD5.lowercased()
    }

    /// `Conflicts/<relativePath>`, then `Conflicts/<dir>/<name>-2.<ext>`, `-3`, … until free.
    public static func conflictPath(for relativePath: String, under destinationRoot: URL, fileManager: FileManager) -> String {
        let base = "\(LibraryMoveFolders.conflicts)/\(relativePath)"
        if !fileManager.fileExists(atPath: destinationRoot.appendingPathComponent(base).path) { return base }
        let ns = base as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(n)" : "\(stem)-\(n).\(ext)"
            if !fileManager.fileExists(atPath: destinationRoot.appendingPathComponent(candidate).path) { return candidate }
            n += 1
        }
    }

    private struct SourceFacts {
        let url: URL
        let size: Int64
        let modified: Date?
        let md5: String?
    }

    /// The source's size, modification date and (under `ROMs/` and `BIOS/`) MD5, or `nil` when it no longer exists.
    private func sourceFacts(of item: LibraryMovePlan.Item, under sourceRoot: URL) throws -> SourceFacts? {
        let source = sourceRoot.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
            WLOG("LibraryMove: \(item.relativePath) disappeared before it was copied; skipping")
            return nil
        }
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let md5 = Self.needsMD5(item.relativePath) ? md5Provider.md5ForFile(at: source, fromOffset: 0) : nil
        return SourceFacts(url: source, size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate, md5: md5)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    private func copyToConflicts(_ item: LibraryMovePlan.Item, _ facts: SourceFacts, destinationRoot: URL) throws -> LibraryMoveJournal.Entry {
        let conflictPath = Self.conflictPath(for: item.relativePath, under: destinationRoot, fileManager: fileManager)
        try copyVerified(from: facts.url, to: destinationRoot.appendingPathComponent(conflictPath), size: facts.size, md5: facts.md5, relativePath: item.relativePath)
        return .init(size: facts.size, md5: facts.md5, modified: facts.modified, state: .conflict, destinationPath: conflictPath)
    }

    /// Stages and verifies the incoming copy first, then moves the existing file to `Conflicts/` and renames the copy
    /// into the real path. Nothing is deleted: if the final rename fails the existing file goes straight back.
    private func copyDisplacingExisting(_ item: LibraryMovePlan.Item, _ facts: SourceFacts, destination: URL, destinationRoot: URL) throws -> LibraryMoveJournal.Entry {
        let partial = try stagePartial(from: facts.url, for: destination, size: facts.size, md5: facts.md5, relativePath: item.relativePath)
        let displacedPath = Self.conflictPath(for: item.relativePath, under: destinationRoot, fileManager: fileManager)
        let displaced = destinationRoot.appendingPathComponent(displacedPath)
        do {
            try fileManager.createDirectory(at: displaced.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: destination, to: displaced)
        } catch {
            try? fileManager.removeItem(at: partial)
            throw error
        }
        do {
            try fileManager.moveItem(at: partial, to: destination)
        } catch {
            try? fileManager.moveItem(at: displaced, to: destination)
            try? fileManager.removeItem(at: partial)
            throw error
        }
        return .init(size: facts.size, md5: facts.md5, modified: facts.modified, state: .displaced, destinationPath: nil, displacedPath: displacedPath)
    }

    private func copyVerified(from source: URL, to target: URL, size: Int64, md5: String?, relativePath: String) throws {
        let partial = try stagePartial(from: source, for: target, size: size, md5: md5, relativePath: relativePath)
        do {
            try fileManager.moveItem(at: partial, to: target)   // throws if target exists: never replaces a file
        } catch {
            try? fileManager.removeItem(at: partial)
            throw error
        }
    }

    /// Copies `source` to the hidden temp file beside `target` and verifies it, with one retry.
    /// - Returns: the verified temp file, ready to be renamed into place.
    private func stagePartial(from source: URL, for target: URL, size: Int64, md5: String?, relativePath: String) throws -> URL {
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let partial = Self.partialURL(for: target)
        for attempt in 1...2 {
            if fileManager.fileExists(atPath: partial.path) { try fileManager.removeItem(at: partial) }
            try fileManager.copyItem(at: source, to: partial)
            if verify(partial, expectedSize: size, expectedMD5: md5) { return partial }
            WLOG("LibraryMove: verification of \(relativePath) failed (attempt \(attempt))")
        }
        try? fileManager.removeItem(at: partial)
        throw LibraryMoveError.verificationFailed(relativePath: relativePath)
    }
}
