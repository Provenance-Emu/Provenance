//
//  LibraryStaging.swift
//  PVLibrarySharing
//
//  Where a copy lands before the importer takes it (spec §3.5).
//

import CryptoKit
import Foundation

/// The folder layout of copies in progress.
///
/// Copies are staged **outside** `Imports/`: that folder is watched, and the
/// watcher would pick up half-written `.part` files, or queue finished ones
/// without the mapped system before the copy hands them over. The importer
/// moves the files out of staging itself (`addImports(forPaths:targetSystem:)`
/// accepts paths anywhere).
///
/// ```
/// <root>/<app>-<hash>/manifest.json     cached pull manifest (iFly pulls are metered)
/// <root>/<app>-<hash>/files/<path>      verified files, peer layout kept
/// <root>/<app>-<hash>/files/<path>.part a download in progress
/// <root>/<app>-<hash>/.handed-off       written once the importer has the files
/// ```
public struct LibraryStaging: Sendable {
    static let manifestName = "manifest.json"
    static let filesFolder = "files"
    static let handedOffMarker = ".handed-off"
    static let partialExtension = "part"
    /// Hex digits of the hash in a folder name: enough to never collide in one library.
    private static let folderHashLength = 16

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// One folder per (peer, item). Named by a hash, never the item id: iFly ids
    /// are `title|platform|size`, and titles can hold `/`, `:` or `..`.
    public func folder(peerKey: String, app: PeerApp, itemId: String) -> URL {
        let digest = SHA256.hash(data: Data("\(peerKey)\n\(app.rawValue)\n\(itemId)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(Self.folderHashLength)
        return root.appendingPathComponent("\(app.rawValue)-\(hex)", isDirectory: true)
    }

    /// `folder/files/<relativePath>`, or nil when the path would land outside
    /// `folder/files` (absolute paths, `..`, empty components).
    public static func containedURL(for relativePath: String, in folder: URL) -> URL? {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }
        let base = folder.appendingPathComponent(filesFolder, isDirectory: true).standardizedFileURL
        let url = base.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(base.path + "/") else { return nil }
        return url
    }

    // MARK: - Cleanup

    /// Marks a folder as handed to the importer, so `sweep` may remove it.
    public func markHandedOff(_ folder: URL, at date: Date = Date()) {
        let marker = folder.appendingPathComponent(Self.handedOffMarker)
        try? Data(ISO8601DateFormatter().string(from: date).utf8).write(to: marker)
    }

    /// Deletes one copy's folder (cancelled for good, or failed for good).
    public func discard(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Removes folders the importer is done with, and abandoned copies.
    ///
    /// - A handed-off folder goes once no file is left under `files/` (the
    ///   importer moved them all), or once it is older than `handedOffAge`
    ///   (the importer skipped a duplicate and left the files behind).
    /// - A folder that never finished goes after `abandonedAge`, measured from
    ///   its last change, so an interrupted copy can still resume for a while.
    public static let defaultHandedOffAge: TimeInterval = 24 * 60 * 60
    public static let defaultAbandonedAge: TimeInterval = 7 * 24 * 60 * 60

    public func sweep(
        now: Date = Date(),
        handedOffAge: TimeInterval = LibraryStaging.defaultHandedOffAge,
        abandonedAge: TimeInterval = LibraryStaging.defaultAbandonedAge
    ) {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return }
        for folder in folders {
            let marker = folder.appendingPathComponent(Self.handedOffMarker)
            if let markerDate = Self.modificationDate(of: marker) {
                let empty = !Self.containsRegularFile(folder.appendingPathComponent(Self.filesFolder))
                if empty || now.timeIntervalSince(markerDate) > handedOffAge {
                    try? manager.removeItem(at: folder)
                }
            } else if let changed = Self.latestModification(in: folder), now.timeIntervalSince(changed) > abandonedAge {
                try? manager.removeItem(at: folder)
            }
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func containsRegularFile(_ folder: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return false }
        let regular: (URL) -> Bool = { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
        for case let url as URL in enumerator where regular(url) {
            return true
        }
        return false
    }

    private static func latestModification(in folder: URL) -> Date? {
        var latest = modificationDate(of: folder)
        let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]
        )
        while let url = enumerator?.nextObject() as? URL {
            if let date = modificationDate(of: url), date > (latest ?? .distantPast) {
                latest = date
            }
        }
        return latest
    }
}

/// Streaming SHA-256 of a file, so a multi-gigabyte image is never in memory.
public enum FileSHA256 {
    private static let chunkSize = 1 << 20

    public static func hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let read = try autoreleasepool { try handle.read(upToCount: chunkSize) }
            guard let chunk = read, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

#if !canImport(ObjectiveC)
/// `autoreleasepool` exists only with the Objective-C runtime.
@inline(__always)
private func autoreleasepool<T>(_ body: () throws -> T) rethrows -> T { try body() }
#endif
