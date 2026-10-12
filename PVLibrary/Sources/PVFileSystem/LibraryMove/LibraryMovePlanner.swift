//
//  LibraryMovePlanner.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Step 1 of a move: list the regular files under the chosen top-level entries, total their
//  size and check the destination volume can hold a second copy (the source is deleted only
//  after the switch, so for a same-volume move the full size must be free).
//

import Foundation
import PVLogging

public struct LibraryMovePlan: Sendable, Equatable {
    public struct Item: Sendable, Equatable {
        /// Relative to the root, e.g. `ROMs/com.provenance.snes/Game.sfc`.
        public let relativePath: String
        public let size: Int64
        public let modified: Date?

        public init(relativePath: String, size: Int64, modified: Date?) {
            self.relativePath = relativePath
            self.size = size
            self.modified = modified
        }
    }

    public let items: [Item]
    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.size } }

    public init(items: [Item]) {
        self.items = items
    }
}

public struct LibraryMovePlanner: Sendable {
    /// Free space must cover the plan plus the larger of this and 5% of the plan.
    public static let minimumHeadroomBytes: Int64 = 200 * 1024 * 1024

    private static let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]

    private let fileManager: FileManager
    /// Free bytes on the volume holding the URL. Injected for tests.
    public let availableCapacity: @Sendable (URL) throws -> Int64

    public init(fileManager: FileManager = .default,
                availableCapacity: @escaping @Sendable (URL) throws -> Int64 = { try LibraryMovePlanner.volumeCapacity($0) }) {
        self.fileManager = fileManager
        self.availableCapacity = availableCapacity
    }

    public static func requiredBytes(for bytes: Int64) -> Int64 {
        bytes + max(minimumHeadroomBytes, bytes / 20)
    }

    /// `volumeAvailableCapacityForImportantUsage`: what iOS would free up for user-initiated work.
    /// tvOS and watchOS do not have that key; they report the plain available capacity.
    public static func volumeCapacity(_ url: URL) throws -> Int64 {
        #if os(tvOS) || os(watchOS)
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(values.volumeAvailableCapacity ?? 0)
        #else
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        return values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        #endif
    }

    /// Every top-level name under `root` that a move carries: folders and loose files, sorted.
    /// Hidden entries, Realm files (names containing `.realm`) and the journal file name are skipped.
    public func topLevelEntries(at root: URL) throws -> [String] {
        try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .map(\.lastPathComponent)
            .filter { !Self.isExcluded(name: $0) }
            .sorted()
    }

    /// Regular files under `root/<name>` for each name that exists. A name may be a directory
    /// (planned recursively) or a regular file (planned as one item). Hidden entries, files
    /// whose name contains `.realm`, and the journal file name are never planned.
    /// - Throws: when anything under a listed name can't be read. A file the plan silently dropped would be skipped by
    ///   the copy, left behind by cleanup and invisible after the switch, so an incomplete plan never proceeds.
    public func plan(root: URL, folders: [String]) throws -> LibraryMovePlan {
        var items: [LibraryMovePlan.Item] = []
        for name in folders where !Self.isExcluded(name: name) {
            let entryURL = root.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: entryURL.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                items.append(contentsOf: try planDirectory(entryURL, under: root))
            } else if let item = try Self.item(for: entryURL, relativePath: name) {
                items.append(item)
            }
        }
        return LibraryMovePlan(items: items.sorted { $0.relativePath < $1.relativePath })
    }

    public func checkSpace(for plan: LibraryMovePlan, at destinationRoot: URL) throws {
        let required = Self.requiredBytes(for: plan.totalBytes)
        let available = try availableCapacity(destinationRoot)
        guard available >= required else {
            throw LibraryMoveError.insufficientSpace(required: required, available: available)
        }
    }

    private func planDirectory(_ directory: URL, under root: URL) throws -> [LibraryMovePlan.Item] {
        var firstError: Error?
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: Array(Self.resourceKeys), options: [.skipsHiddenFiles],
                                                      errorHandler: { _, error in
                                                          if firstError == nil, !Self.isVanished(error) { firstError = error }
                                                          return true
                                                      }) else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: directory.path])
        }
        var items: [LibraryMovePlan.Item] = []
        for case let url as URL in enumerator {
            if Self.isExcluded(name: url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard let relative = Self.relativePath(of: url, under: root) else {
                throw CocoaError(.fileReadInvalidFileName, userInfo: [NSFilePathErrorKey: url.path])
            }
            if let item = try Self.item(for: url, relativePath: relative) {
                items.append(item)
            }
        }
        if let firstError { throw firstError }
        return items
    }

    /// The plan item for `url` if it is a regular file. Directories are walked by the caller; anything else (a symlink,
    /// a socket) can't be copied and is logged as left behind.
    private static func item(for url: URL, relativePath: String) throws -> LibraryMovePlan.Item? {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: resourceKeys)
        } catch where isVanished(error) {
            return nil
        }
        if values.isRegularFile == true {
            return LibraryMovePlan.Item(relativePath: relativePath, size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
        }
        if values.isDirectory != true {
            WLOG("LibraryMove: leaving \(relativePath) behind: not a regular file")
        }
        return nil
    }

    /// A file that disappeared between the listing and the read (the app is still running during the copy phase) is
    /// skipped, like the copier skips a vanished source; any other error means the plan is incomplete.
    private static func isVanished(_ error: Error) -> Bool {
        let code = (error as? CocoaError)?.code
        return code == .fileNoSuchFile || code == .fileReadNoSuchFile
    }

    private static func isExcluded(name: String) -> Bool {
        name.hasPrefix(".") || name.contains(LibraryMoveFolders.realmMarker) || LibraryMoveFolders.neverMoved.contains(name)
    }

    /// Strips `root` from `url`, accepting either side in its raw or symlink-resolved form (`/var` vs `/private/var`).
    static func relativePath(of url: URL, under root: URL) -> String? {
        let candidates = [url.standardizedFileURL.path, url.resolvingSymlinksInPath().path]
        let bases = [root.standardizedFileURL.path, root.resolvingSymlinksInPath().path].map { $0.hasSuffix("/") ? $0 : $0 + "/" }
        for path in candidates {
            for base in bases where path.hasPrefix(base) {
                return String(path.dropFirst(base.count))
            }
        }
        return nil
    }
}
