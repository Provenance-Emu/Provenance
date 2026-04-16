//
//  FileLocationResolver.swift
//  PVFileSystem
//
//  Single source of truth for resolving partial paths to actual file URLs.
//  All code that needs to locate a file — PVFile.url, CloudKit sync,
//  import pipeline, UI layer — should go through this resolver instead
//  of constructing paths ad-hoc.
//
//  Created by Joseph Mattiello on 4/16/26.
//

import Foundation
import PVLogging
import PVSettings
import Defaults

// MARK: - Resolution Result

/// Where a file was found (or not).
public enum FileResolution: Sendable, Equatable {
    /// File exists at a local path (Documents on iOS, Caches on tvOS).
    case local(URL)
    /// File exists in the iCloud Drive container.
    case cloudDrive(URL)
    /// File was not found at any known location.
    case notFound

    /// The resolved URL, or `nil` if `.notFound`.
    public var url: URL? {
        switch self {
        case .local(let u), .cloudDrive(let u): return u
        case .notFound: return nil
        }
    }

    /// `true` when the file is available locally (no download needed).
    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }
}

// MARK: - FileLocationResolver

/// Resolves `partialPath` strings (stored in PVFile / Realm) to actual
/// filesystem URLs using a priority-ordered search:
///
/// 1. **Local directory** (Documents on iOS, Caches on tvOS)
/// 2. **iCloud Drive container** (when iCloud Drive sync mode is active)
///
/// Local always wins — a file that exists in both places resolves to the
/// local copy so that sync backends don't "steal" locally-imported games.
///
/// ## Batch Operations
///
/// For checking many files at once (e.g. library refresh), use
/// ``buildLocalFileIndex(under:)`` to scan directories once and get a
/// `Set<String>` of known relative paths, then check membership with
/// ``existsInIndex(_:index:)`` — O(n) scan + O(1) per lookup instead
/// of N individual `fileExists` syscalls.
public final class FileLocationResolver: @unchecked Sendable {

    public static let shared = FileLocationResolver()

    private init() {}

    // MARK: - Base URLs

    /// Platform-appropriate local base directory.
    /// Documents on iOS/macOS, Caches on tvOS.
    public var localBaseURL: URL {
        #if os(tvOS)
        return URL.cachesPath
        #else
        return URL.documentsPath
        #endif
    }

    /// iCloud Drive container URL, if available.
    /// Returns `nil` when iCloud is not configured or on tvOS.
    public var iCloudContainerURL: URL? {
        #if os(tvOS)
        return nil
        #else
        return URL.iCloudContainerDirectory
        #endif
    }

    /// Whether iCloud Drive sync mode is currently active.
    public var isICloudDriveMode: Bool {
        #if os(tvOS)
        return false
        #else
        return Defaults[.iCloudSyncMode].isICloudDrive
        #endif
    }

    // MARK: - Single File Resolution

    /// Resolve a partial path to its actual storage location.
    ///
    /// Always checks local first, then iCloud Drive container.
    /// Returns `.notFound` if the file doesn't exist anywhere.
    ///
    /// - Parameter partialPath: Relative path as stored in PVFile
    ///   (e.g. `"com.provenance.snes/Game.sfc"`).
    /// - Returns: A ``FileResolution`` indicating where the file was found.
    public func resolve(_ partialPath: String) -> FileResolution {
        let fm = FileManager.default

        // 1. Always check local first
        let localURL = localBaseURL.appendingPathComponent(partialPath)
        if fm.fileExists(atPath: localURL.path) {
            return .local(localURL)
        }

        // 2. Check iCloud Drive container (iOS/macOS only, Drive mode only)
        #if !os(tvOS)
        if isICloudDriveMode, let container = iCloudContainerURL {
            let driveURL = container.appendingPathComponent(partialPath)
            if fm.fileExists(atPath: driveURL.path) {
                return .cloudDrive(driveURL)
            }
        }
        #endif

        return .notFound
    }

    /// Returns the best available URL for a partial path (local preferred),
    /// falling back to the expected local URL even if the file doesn't exist.
    ///
    /// Use this as a drop-in replacement for PVFile.url when you need a
    /// non-nil URL (e.g. for download destinations or display purposes).
    public func bestURL(for partialPath: String) -> URL {
        switch resolve(partialPath) {
        case .local(let url), .cloudDrive(let url):
            return url
        case .notFound:
            // Return expected local URL for download destinations
            return expectedLocalURL(for: partialPath)
        }
    }

    /// Returns the expected local URL without checking file existence.
    /// Use for download destinations or path construction.
    public func expectedLocalURL(for partialPath: String) -> URL {
        localBaseURL.appendingPathComponent(partialPath)
    }

    /// Returns `true` if the file exists at any known location.
    public func fileExists(_ partialPath: String) -> Bool {
        resolve(partialPath) != .notFound
    }

    // MARK: - Batch Operations

    /// Scan a directory tree once and return a set of relative paths that
    /// exist on disk.
    ///
    /// This is dramatically faster than calling `fileExists` for each game
    /// individually — one directory enumeration (O(n)) instead of N
    /// separate `stat()` syscalls.
    ///
    /// - Parameter subdirectory: Optional subdirectory under `localBaseURL`
    ///   to scope the scan (e.g. `"com.provenance.snes"`). Pass `nil` to
    ///   scan the entire local directory tree.
    /// - Returns: A set of relative paths (relative to `localBaseURL`).
    public func buildLocalFileIndex(under subdirectory: String? = nil) -> Set<String> {
        let scanURL: URL
        if let sub = subdirectory {
            scanURL = localBaseURL.appendingPathComponent(sub)
        } else {
            scanURL = localBaseURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: scanURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            WLOG("FileLocationResolver: failed to enumerate \(scanURL.path)")
            return []
        }

        let basePrefix = localBaseURL.path + "/"
        var index = Set<String>()

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            // Store path relative to localBaseURL
            let fullPath = fileURL.path
            if fullPath.hasPrefix(basePrefix) {
                let relativePath = String(fullPath.dropFirst(basePrefix.count))
                index.insert(relativePath)
            }
        }

        return index
    }

    /// Build a filename-to-relative-path lookup for fast existence checks
    /// by filename alone.
    ///
    /// Useful when you have a list of filenames (from Realm) and want to
    /// check which ones have files on disk without knowing the exact
    /// subdirectory.
    ///
    /// - Parameter subdirectory: Optional scope.
    /// - Returns: Dictionary mapping lowercased filename → relative path.
    public func buildFilenameIndex(under subdirectory: String? = nil) -> [String: String] {
        let index = buildLocalFileIndex(under: subdirectory)
        var filenameMap = [String: String]()
        filenameMap.reserveCapacity(index.count)
        for path in index {
            let filename = (path as NSString).lastPathComponent.lowercased()
            filenameMap[filename] = path
        }
        return filenameMap
    }

    /// Check if a partial path exists in a pre-built index.
    ///
    /// Normalizes the path before lookup (strips leading `/`, collapses
    /// double slashes).
    public func existsInIndex(_ partialPath: String, index: Set<String>) -> Bool {
        var normalized = partialPath
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }
        normalized = normalized.replacingOccurrences(of: "//", with: "/")
        return index.contains(normalized)
    }
}
