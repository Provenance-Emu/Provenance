//
//  LibraryMoveFileCopier.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Moves one planned file: copy, verify (size always; MD5 under ROMs/ and BIOS/), and the
//  conflict rule (never overwrite; a different file of the same name goes to Conflicts/).
//  The source is left in place; cleanup deletes it after the switch.
//

import Foundation
import PVHashing
import PVLogging

public struct LibraryMoveFileCopier: Sendable {
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
    /// - Returns: the journal entry, or `nil` when the source no longer exists (skipped, not an error).
    /// - Throws: `LibraryMoveError.verificationFailed` after one retry; file-system errors as thrown.
    public func transfer(_ item: LibraryMovePlan.Item, from sourceRoot: URL, to destinationRoot: URL) throws -> LibraryMoveJournal.Entry? {
        let source = sourceRoot.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
            WLOG("LibraryMove: \(item.relativePath) disappeared before it was copied; skipping")
            return nil
        }
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = Int64(values.fileSize ?? 0)
        let modified = values.contentModificationDate
        let md5 = Self.needsMD5(item.relativePath) ? md5Provider.md5ForFile(at: source, fromOffset: 0) : nil

        let destination = destinationRoot.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: destination.path) else {
            try copyVerified(from: source, to: destination, size: size, md5: md5, relativePath: item.relativePath)
            return .init(size: size, md5: md5, modified: modified, state: .copied, destinationPath: nil)
        }
        if verify(destination, expectedSize: size, expectedMD5: md5) {
            return .init(size: size, md5: md5, modified: modified, state: .identical, destinationPath: nil)
        }
        let conflictPath = Self.conflictPath(for: item.relativePath, under: destinationRoot, fileManager: fileManager)
        try copyVerified(from: source, to: destinationRoot.appendingPathComponent(conflictPath), size: size, md5: md5, relativePath: item.relativePath)
        return .init(size: size, md5: md5, modified: modified, state: .conflict, destinationPath: conflictPath)
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

    private func copyVerified(from source: URL, to target: URL, size: Int64, md5: String?, relativePath: String) throws {
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        for attempt in 1...2 {
            if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
            try fileManager.copyItem(at: source, to: target)
            if verify(target, expectedSize: size, expectedMD5: md5) { return }
            WLOG("LibraryMove: verification of \(relativePath) failed (attempt \(attempt))")
        }
        try? fileManager.removeItem(at: target)
        throw LibraryMoveError.verificationFailed(relativePath: relativePath)
    }
}
