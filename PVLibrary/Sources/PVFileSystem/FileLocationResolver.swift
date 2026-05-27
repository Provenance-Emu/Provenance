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

    /// Base URL for resolving partialPaths under iCloud Drive.
    ///
    /// Returns `<ubiquityContainer>/Documents/` — the root of the ubiquity
    /// Documents folder, NOT the raw container. Files synced via iCloud Drive
    /// live at `<ubiquityContainer>/Documents/<partialPath>`, so callers should
    /// treat this as a drop-in peer of `localBaseURL`.
    ///
    /// Returns `nil` when iCloud is not configured or on tvOS.
    public var iCloudBaseURL: URL? {
        #if os(tvOS)
        return nil
        #else
        return URL.iCloudDocumentsDirectory
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
        if isICloudDriveMode, let container = iCloudBaseURL {
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

    // MARK: - Filename Fallback

    /// Locate a file by its basename within a subdirectory, ignoring the
    /// stored partial path.
    ///
    /// Use when ``resolve(_:)`` returns ``FileResolution/notFound`` but you
    /// suspect the file is present under a different relative path (e.g. the
    /// importer wrote it with a different case, separator, or trailing
    /// whitespace than what was persisted in `PVFile.partialPath`).
    ///
    /// The match is case-insensitive and scoped to immediate files under
    /// `subdirectory`; it does not recurse deeply to avoid false positives
    /// across unrelated systems.
    ///
    /// - Parameters:
    ///   - subdirectory: Relative path under ``localBaseURL`` to scan
    ///     (e.g. `"com.provenance.jaguar"`).
    ///   - filename: The filename to look for (e.g. `"Game.j64"`).
    /// - Returns: ``FileResolution/local(_:)`` or ``FileResolution/cloudDrive(_:)``
    ///   on a match, otherwise ``FileResolution/notFound``.
    public func resolveByFilename(under subdirectory: String, filename: String) -> FileResolution {
        guard !filename.isEmpty else { return .notFound }
        let lowered = filename.lowercased()

        // ROMs live under "ROMs/<systemID>/" while save states / BIOS use the
        // raw subdirectory. Try both layouts so this resolver works for any
        // file type.
        let romsScopedSubdir = "ROMs/" + subdirectory
        let candidateLocalDirs = [
            localBaseURL.appendingPathComponent(romsScopedSubdir),
            localBaseURL.appendingPathComponent(subdirectory)
        ]
        for dir in candidateLocalDirs {
            if let match = firstMatch(in: dir, filename: lowered) {
                return .local(match)
            }
        }

        #if !os(tvOS)
        if isICloudDriveMode, let container = iCloudBaseURL {
            let candidateCloudDirs = [
                container.appendingPathComponent(romsScopedSubdir),
                container.appendingPathComponent(subdirectory)
            ]
            for dir in candidateCloudDirs {
                if let match = firstMatch(in: dir, filename: lowered) {
                    return .cloudDrive(match)
                }
            }
        }
        #endif

        return .notFound
    }

    /// Combined resolution: try `partialPath` first, then fall back to
    /// filename-under-system-directory matching.
    ///
    /// Use this whenever a stored `partialPath` may have drifted from the
    /// actual on-disk layout (e.g. CloudKit-created `PVGame` whose file was
    /// later imported locally under a slightly different relative path).
    ///
    /// - Parameters:
    ///   - partialPath: The stored `PVFile.partialPath`, if any.
    ///   - systemIdentifier: The game's `systemIdentifier` used as the
    ///     subdirectory to scope filename fallback.
    ///   - candidateFilenames: Filenames to try for the fallback, in priority
    ///     order (typically `[file.fileName, romPath.lastPathComponent]`).
    /// - Returns: A ``FileResolution`` — `.local(_)` / `.cloudDrive(_)` if
    ///   found, otherwise `.notFound`.
    public func resolve(partialPath: String?,
                        systemIdentifier: String?,
                        candidateFilenames: [String]) -> FileResolution {
        if let partialPath, !partialPath.isEmpty {
            let primary = resolve(partialPath)
            if primary != .notFound {
                return primary
            }
        }
        guard let systemID = systemIdentifier, !systemID.isEmpty else {
            return .notFound
        }
        for name in candidateFilenames where !name.isEmpty {
            let match = resolveByFilename(under: systemID, filename: name)
            if match != .notFound {
                return match
            }
        }
        return .notFound
    }

    /// Compute a relative path (under `localBaseURL` or iCloud container)
    /// for a resolved URL. Returns `nil` when the URL sits outside known
    /// base locations. Tolerates the `/var` ↔ `/private/var` symlink that
    /// iOS uses for the sandbox.
    public func relativePath(for url: URL) -> String? {
        if let stripped = stripPrefix(url: url, base: localBaseURL) {
            return stripped
        }
        #if !os(tvOS)
        if let container = iCloudBaseURL,
           let stripped = stripPrefix(url: url, base: container) {
            return stripped
        }
        #endif
        return nil
    }

    /// Drop `base` from the front of `url`, accepting either the raw or
    /// symlink-resolved form of the base prefix.
    private func stripPrefix(url: URL, base: URL) -> String? {
        let urlPath = url.path
        let rawBase = base.path
        let resolvedBase = base.resolvingSymlinksInPath().path
        for candidate in [rawBase, resolvedBase] {
            let prefix = candidate.hasSuffix("/") ? candidate : candidate + "/"
            if urlPath.hasPrefix(prefix) {
                return String(urlPath.dropFirst(prefix.count))
            }
        }
        return nil
    }

    private func firstMatch(in directory: URL, filename lowered: String) -> URL? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        guard let entries = try? fm.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: [.isRegularFileKey],
                                                        options: [.skipsHiddenFiles]) else {
            return nil
        }
        return entries.first { url in
            url.lastPathComponent.lowercased() == lowered
        }
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
        return enumerateRelativePaths(base: localBaseURL, subdirectory: subdirectory)
    }

    /// Scan every base where ROM/save files may live (local Documents/Caches
    /// plus the iCloud Drive Documents folder when in iCloud Drive mode) and
    /// return the union of relative paths.
    ///
    /// Use this for availability checks where "downloaded" means "the file is
    /// reachable through any supported storage" (local OR ubiquity).
    ///
    /// - Parameter subdirectory: Optional subdirectory to scope the scan.
    /// - Returns: Union of relative paths across all bases.
    public func buildAvailabilityIndex(under subdirectory: String? = nil) -> Set<String> {
        var index = enumerateRelativePaths(base: localBaseURL, subdirectory: subdirectory)
        #if !os(tvOS)
        if isICloudDriveMode, let cloudBase = iCloudBaseURL {
            index.formUnion(enumerateRelativePaths(base: cloudBase, subdirectory: subdirectory))
        }
        #endif
        return index
    }

    private func enumerateRelativePaths(base: URL, subdirectory: String?) -> Set<String> {
        // Use the URL-based enumerator with prefetched resource keys.
        // Unlike `enumerator(atPath:)` whose `.fileAttributes` triggers a
        // per-file stat() syscall, the URL variant uses getdirentriesattr
        // to batch-fetch requested properties during directory traversal —
        // orders of magnitude faster for large ROM libraries (Sentry
        // PROVENANCE-12S / 17C / 160: MXCPUException from per-file stat).
        let scanURL: URL
        if let sub = subdirectory {
            scanURL = base.appendingPathComponent(sub)
        } else {
            scanURL = base
        }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: scanURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            WLOG("FileLocationResolver: failed to enumerate \(scanURL.path)")
            return []
        }

        let basePath = base.standardizedFileURL.path
        let basePrefix = basePath.hasSuffix("/") ? basePath : basePath + "/"

        var index = Set<String>()
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                  resourceValues.isRegularFile == true else { continue }
            let fullPath = fileURL.standardizedFileURL.path
            guard fullPath.hasPrefix(basePrefix) else { continue }
            let relativePath = String(fullPath.dropFirst(basePrefix.count))
            if !relativePath.isEmpty {
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
