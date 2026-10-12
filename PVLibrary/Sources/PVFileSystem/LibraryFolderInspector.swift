//
//  LibraryFolderInspector.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Checks a folder the user picked before any move: it must be a directory outside the library's own
//  folders, writable in place, and the UI needs to know what kind of place it is (D16, D12).
//

import Foundation

public enum LibraryFolderKind: String, Sendable, Equatable {
    /// Under this app's Documents ("On My iPhone › Provenance › …"): local, fast, survives other apps. Recommended.
    case ownDocuments
    /// Another app's container: the folder disappears when that app is deleted. Warn.
    case otherAppDocuments
    /// Files may be cloud-only placeholders until downloaded.
    case iCloudDrive
    /// On My iPhone, or a file provider; iOS paths cannot tell them apart. The write probe is the gate.
    case filesFolder
}

public struct LibraryFolderInspection: Sendable, Equatable {
    public let url: URL
    public let kind: LibraryFolderKind
    /// `LibraryManifest.fileName` is present: picking it means joining that library (phase 4).
    public let hasManifest: Bool
    public let availableBytes: Int64
}

public struct LibraryFolderInspector: Sendable {
    static let probePrefix = ".provenance-write-probe-"

    private let fileManager: FileManager
    private let appDocuments: URL
    private let libraryRoots: @Sendable () -> [URL]
    private let availableCapacity: @Sendable (URL) throws -> Int64

    public init(fileManager: FileManager = .default,
                appDocuments: URL = URL.documentsPathLocal,
                libraryRoots: @escaping @Sendable () -> [URL] = { [LibraryLocation.current.rootURL, LibraryLocation.current.savesRootURL] },
                availableCapacity: @escaping @Sendable (URL) throws -> Int64 = { try LibraryMovePlanner.volumeCapacity($0) }) {
        self.fileManager = fileManager
        self.appDocuments = appDocuments
        self.libraryRoots = libraryRoots
        self.availableCapacity = availableCapacity
    }

    public func inspect(_ url: URL) throws -> LibraryFolderInspection {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryFolderError.notADirectory(url.path)
        }
        let folders = LibraryMoveFolders.shared + LibraryMoveFolders.saves
        for root in libraryRoots() where Self.conflicts(url, withRoot: root, folders: folders) {
            throw LibraryFolderError.isCurrentRoot(url.path)
        }
        try probeWrite(url)
        let isUbiquitous = (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) ?? false
        let kind = Self.classify(path: Self.canonical(url), appDocumentsPath: Self.canonical(appDocuments), isUbiquitous: isUbiquitous)
        return LibraryFolderInspection(url: url.standardizedFileURL, kind: kind,
                                       hasManifest: LibraryManifest.exists(in: url, fileManager: fileManager),
                                       availableBytes: try availableCapacity(url))
    }

    static func classify(path: String, appDocumentsPath: String, isUbiquitous: Bool) -> LibraryFolderKind {
        if isUbiquitous || path.contains("/Mobile Documents/") { return .iCloudDrive }
        if path == appDocumentsPath || path.hasPrefix(appDocumentsPath + "/") { return .ownDocuments }
        if path.contains("/Containers/Data/Application/") { return .otherAppDocuments }
        return .filesFolder
    }

    /// `url` is the root, contains it, or is one of (or inside) the folders the library owns under it.
    /// A sibling subfolder of the root (`Documents/MyLib`) is fine (D12).
    static func conflicts(_ url: URL, withRoot root: URL, folders: [String]) -> Bool {
        let picked = canonical(url)
        let base = canonical(root)
        if picked == base || base.hasPrefix(picked + "/") { return true }
        return folders.contains { picked == base + "/" + $0 || picked.hasPrefix(base + "/" + $0 + "/") }
    }

    static func canonical(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func probeWrite(_ url: URL) throws {
        let probe = url.appendingPathComponent(Self.probePrefix + UUID().uuidString, isDirectory: false)
        do {
            try Data().write(to: probe)
            try fileManager.removeItem(at: probe)
        } catch {
            try? fileManager.removeItem(at: probe)
            throw LibraryFolderError.notWritable(url.path)
        }
    }
}
