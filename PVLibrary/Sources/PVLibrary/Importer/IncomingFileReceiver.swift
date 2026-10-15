//
//  IncomingFileReceiver.swift
//  PVLibrary
//
//  Copies a file handed to the app ("Open in", a sibling app's share sheet, AirDrop)
//  into the import folder. Foundation only, so it can be tested on its own.
//

import Foundation

public enum IncomingFileReceiver {

    /// Prefix of the hidden name a copy has until it is complete; the directory
    /// watcher skips hidden files, so a file it sees is never half-written.
    static let partialCopyPrefix = ".incoming-"

    /// The app's own document Inbox, where iOS puts a copy of a shared file when it
    /// does not open the original in place. Always the container's Documents, never
    /// the app group, whatever library location is chosen.
    public static var inboxDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    /// Copies `source` into `directory` under a free name and returns the copy.
    ///
    /// With `LSSupportsOpeningDocumentsInPlace` the URL can be the sender's original,
    /// so it is only ever copied, inside its security scope. The source is deleted
    /// afterwards only when it sits in `inbox`: that copy is the app's own, and a
    /// stale one would make iOS rename the next file with the same name (`name-1.ext`).
    @discardableResult
    public static func receive(
        _ source: URL,
        into directory: URL,
        inbox: URL? = inboxDirectory,
        fileManager: FileManager = .default
    ) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent(
            partialCopyPrefix + UUID().uuidString + "-" + source.lastPathComponent, isDirectory: false)
        try fileManager.copyItem(at: source, to: staging)

        let destination = uniqueDestination(
            directory.appendingPathComponent(source.lastPathComponent, isDirectory: false),
            fileManager: fileManager)
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }

        if let inbox, isInside(source, directory: inbox) {
            try? fileManager.removeItem(at: source)
        }
        return destination
    }

    /// `candidate` if nothing is there, otherwise `name-1.ext`, `name-2.ext`, … (the first free one).
    public static func uniqueDestination(_ candidate: URL, fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }
        let directory = candidate.deletingLastPathComponent()
        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        for index in 1..<10_000 {
            let name = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            let url = directory.appendingPathComponent(name, isDirectory: false)
            if !fileManager.fileExists(atPath: url.path) { return url }
        }
        return candidate
    }

    /// Whether `url` is `directory` or inside it (symlinks such as /private/var resolved).
    public static func isInside(_ url: URL, directory: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.path
        return path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
