//
//  LibraryFolderBookmark.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The security-scoped bookmark that keeps access to a folder the user picked in Files: made once
//  from the picker's URL, resolved at every launch, and kept open for the life of the process.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md ("How a user-picked folder works").
//

import Foundation

public enum LibraryFolderError: Error, Equatable, LocalizedError {
    /// `URL(resolvingBookmarkData:)` threw: the folder was deleted, iCloud was signed out, or the provider app is gone.
    case bookmarkUnresolvable(String)
    /// The bookmark resolved but nothing readable is at the path.
    case unreachable(String)
    case notADirectory(String)
    /// The folder is the library root, contains it, or sits inside a folder the library owns.
    case isCurrentRoot(String)
    /// A hidden probe file could not be created and deleted: read-only, or a provider without in-place writes.
    case notWritable(String)
    /// `switchStored(to: .pickedFolder, pickedFolder: nil)`.
    case missingPickedFolder

    public var errorDescription: String? {
        switch self {
        case .bookmarkUnresolvable(let detail): return "The library folder can't be opened: \(detail)"
        case .unreachable(let path): return "The library folder is not reachable: \(path)"
        case .notADirectory(let path): return "\(path) is not a folder."
        case .isCurrentRoot(let path): return "\(path) is already part of the library."
        case .notWritable(let path): return "Provenance can't write to \(path). Choose a folder in On My iPhone or iCloud Drive."
        case .missingPickedFolder: return "No folder was given for the picked-folder location."
        }
    }
}

public enum LibraryFolderBookmark {
    public struct Resolution: Equatable, Sendable {
        public let url: URL
        /// The system wants a fresh bookmark; the caller re-saves one made from `url`.
        public let isStale: Bool
    }

    #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif

    /// Bookmark data for `url`. Access is started first: the picker's URL needs it before any file operation,
    /// including this one. The Bool result is ignored on purpose: `false` only means the URL was never
    /// security-scoped (a plain path, as in tests), not that access was refused.
    public static func make(from url: URL) throws -> Data {
        _ = url.startAccessingSecurityScopedResource()
        return try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves the bookmark and starts accessing the folder. The access is never stopped: cores open files
    /// by path for the life of the process.
    public static func resolve(_ data: Data, fileManager: FileManager = .default) throws -> Resolution {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: data, options: resolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw LibraryFolderError.bookmarkUnresolvable(error.localizedDescription)
        }
        _ = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw LibraryFolderError.unreachable(url.path)
        }
        guard isDirectory.boolValue else { throw LibraryFolderError.notADirectory(url.path) }
        return Resolution(url: url.standardizedFileURL, isStale: isStale)
    }
}
