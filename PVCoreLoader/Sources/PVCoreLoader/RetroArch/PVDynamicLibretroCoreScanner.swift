//
//  PVDynamicLibretroCoreScanner.swift
//  PVCoreLoader
//
//  Created by Claude (Agent) on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Scans the app bundle's Frameworks/ directory at boot time for bare libretro
//  dylibs (`.dylib` or `.libretro.framework`) that are NOT already represented
//  by a static PVRetroArch sub-core plist entry.
//
//  Discovered cores are registered as synthetic sub-cores of the
//  "PVThinLibretro" virtual parent core, which maps them into the
//  normal Provenance core-selection UI.
//
//  Performance strategy
//  ────────────────────
//  dlopen on iOS validates code-signing for every framework it loads, taking
//  ~1 second per binary. With 30+ cores this would add 10–30 s to startup.
//
//  We avoid this by persisting probe results to a JSON file in Library/Caches,
//  keyed by (path, modificationDate). On subsequent launches every cache-hit
//  skips dlopen entirely. Only new or updated frameworks trigger a probe, and
//  those are probed concurrently via DispatchQueue.concurrentPerform.
//
//  Typical cost:
//    First launch: O(n × ~1 s / thread_pool_size)  — unavoidable
//    Later launches: O(1) — just reading a small JSON file + stat()
//
//  Design goals (from issues #2624 and #2639):
//  ─────────────────────────────────────────
//  1. No RetroArch binary required — each discovered dylib is loaded via
//     the thin PVThinLibretroFrontend (libretro.h only).
//  2. Backward compatibility — existing PVRetroArch sub-core associations
//     (ROM library, save states, screenshots, cheats) are preserved by
//     keeping the same core identifiers when a matching sub-core exists.
//  3. Auto-migration — when a "broken" native PV* core (e.g. PVFlycast)
//     and a working `.libretro.framework` dylib for the same system both
//     exist, the scanner can optionally inject the dylib as the preferred
//     core for those systems.
//

import Foundation
import os
import PVLogging
import PVPlists
import PVSupport

#if canImport(Darwin)
import Darwin
#endif

// ---------------------------------------------------------------------------
// MARK: - DiscoveredLibretroCore
// ---------------------------------------------------------------------------

/// Metadata about a libretro core found on the filesystem.
public struct DiscoveredLibretroCore: Sendable, Hashable {

    /// The path to the dylib or framework executable that can be dlopened.
    public let executablePath: URL

    /// Core name from `retro_get_system_info.library_name`.
    public let libraryName: String

    /// Version string from `retro_get_system_info.library_version`.
    public let libraryVersion: String

    /// Pipe-separated extension list from `retro_get_system_info.valid_extensions`.
    public let validExtensions: [String]

    /// Whether the core requires a full path (cannot load ROM from memory).
    public let needFullPath: Bool

    /// A synthetic identifier in the form `<name>.libretro.framework` so it matches
    /// the convention already used by PVRetroArch sub-core identifiers.
    public var syntheticIdentifier: String {
        let slug = libraryName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "\(slug).libretro.framework"
    }
}

// ---------------------------------------------------------------------------
// MARK: - Disk cache helpers (file-private)
// ---------------------------------------------------------------------------

private struct ScanCacheEntry: Codable {
    let path: String
    let modificationDate: Date
    let libraryName: String
    let libraryVersion: String
    let validExtensions: [String]
    let needFullPath: Bool
}

private struct ScanCache: Codable {
    static let currentVersion = 1
    var version: Int = ScanCache.currentVersion
    var entries: [String: ScanCacheEntry] = [:]   // keyed by path
}

// ---------------------------------------------------------------------------
// MARK: - PVDynamicLibretroCoreScanner
// ---------------------------------------------------------------------------

/// Singleton that discovers libretro core dylibs at runtime and synthesises
/// `EmulatorCoreInfoPlist` entries for them so they appear in the core picker.
public final class PVDynamicLibretroCoreScanner: Sendable {

    public static let shared = PVDynamicLibretroCoreScanner()
    private init() {}

    // ---------------------------------------------------------------------------
    // MARK: - Feature flag gate
    // ---------------------------------------------------------------------------

    /// UserDefaults key used by `isFeatureEnabled` for direct boolean overrides
    /// and as the key inside `PVFeatureFlagsDebugOverrides`.
    /// Mirrors `PVFeature.dynamicLibretroScanner.rawValue` in PVFeatureFlags.
    public static let featureFlagKey = "dynamicLibretroScanner"

    /// Returns `true` when the dynamic scanner is enabled.
    ///
    /// Checks (in order):
    /// 1. `PVFeatureFlagsDebugOverrides` dict — set via the feature-flag debug UI
    /// 2. A direct UserDefaults boolean under `featureFlagKey`
    ///
    /// **Off by default** — enable to test buildbot-style libretro cores.
    public static var isFeatureEnabled: Bool {
        if let overrides = UserDefaults.standard.dictionary(forKey: "PVFeatureFlagsDebugOverrides") {
            let entry = overrides[featureFlagKey]
            if let boolValue = entry as? Bool { return boolValue }
            // "nil" sentinel means explicitly cleared — fall through
        }
        return UserDefaults.standard.bool(forKey: featureFlagKey)
    }

    // In-memory store populated by scan().
    private let discoveredStorage = OSAllocatedUnfairLock<[String: DiscoveredLibretroCore]>(initialState: [:])

    // ---------------------------------------------------------------------------
    // MARK: - Disk cache URL
    // ---------------------------------------------------------------------------

    private static var diskCacheURL: URL? {
        guard let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches.appendingPathComponent("com.provenance.libretro-scan-cache.json")
    }

    // ---------------------------------------------------------------------------
    // MARK: - Scan
    // ---------------------------------------------------------------------------

    /// Scans the app bundle's `Frameworks/` directory for libretro dylibs not
    /// already in `knownIdentifiers`.
    ///
    /// Probe results are persisted to disk keyed by `(path, modificationDate)`.
    /// On subsequent launches, cached entries skip `dlopen` entirely — startup
    /// cost drops from O(n × 1 s) to O(1) after the first run.
    ///
    /// - Parameters:
    ///   - knownIdentifiers: Core identifiers already registered via static plists.
    ///     Matching cores are skipped.
    ///   - onProgress: Optional progress callback invoked during the probe phase.
    ///     Called from a background thread; dispatch to MainActor if updating UI.
    ///     Parameters: (completedCount, totalCount, currentCoreName).
    /// - Returns: Newly discovered cores (may be empty if cache is warm).
    @discardableResult
    public func scan(
        knownIdentifiers: Set<String> = [],
        onProgress: (@Sendable (_ completed: Int, _ total: Int, _ currentName: String) -> Void)? = nil
    ) -> [DiscoveredLibretroCore] {
        ILOG("DynamicLibretroScanner: starting scan (knownIdentifiers: \(knownIdentifiers.count))")

        let candidates = collectCandidateExecutables()
        ILOG("DynamicLibretroScanner: \(candidates.count) candidate paths found")
        guard !candidates.isEmpty else { return [] }

        // ── Load disk cache ────────────────────────────────────────────────
        var diskCache = loadDiskCache()
        var cacheModified = false

        // ── Partition candidates into cache-hits and misses ────────────────
        let fm = FileManager.default
        var cacheHits:  [DiscoveredLibretroCore] = []
        var cacheMisses: [URL] = []

        for url in candidates {
            let path = url.path
            let mtime = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date

            if let entry = diskCache.entries[path],
               let mtime,
               abs(entry.modificationDate.timeIntervalSince(mtime)) < 1 {
                // Cache hit — reconstruct without dlopen
                let core = DiscoveredLibretroCore(
                    executablePath:  url,
                    libraryName:     entry.libraryName,
                    libraryVersion:  entry.libraryVersion,
                    validExtensions: entry.validExtensions,
                    needFullPath:    entry.needFullPath
                )
                cacheHits.append(core)
            } else {
                cacheMisses.append(url)
            }
        }

        ILOG("DynamicLibretroScanner: \(cacheHits.count) cache hits, \(cacheMisses.count) need dlopen")

        // ── Probe cache misses concurrently ───────────────────────────────
        // dlopen/dlclose are thread-safe on Darwin.
        let probedResults = OSAllocatedUnfairLock<[(URL, DiscoveredLibretroCore)]>(initialState: [])

        if !cacheMisses.isEmpty {
            let total = candidates.count
            let completedCount = OSAllocatedUnfairLock<Int>(initialState: cacheHits.count)

            // Report initial progress for cache hits
            if let onProgress, !cacheHits.isEmpty {
                onProgress(cacheHits.count, total, "")
            }

            DispatchQueue.concurrentPerform(iterations: cacheMisses.count) { i in
                let url = cacheMisses[i]
                let coreName = url.deletingLastPathComponent().lastPathComponent
                guard let core = self.probe(executableURL: url) else {
                    let n = completedCount.withLock { count -> Int in count += 1; return count }
                    onProgress?(n, total, coreName)
                    return
                }
                probedResults.withLock { $0.append((url, core)) }
                let n = completedCount.withLock { count -> Int in count += 1; return count }
                onProgress?(n, total, core.libraryName)
            }

            // Update disk cache with newly probed results
            for (url, core) in probedResults.withLock({ $0 }) {
                let path = url.path
                let mtime = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date ?? Date()
                diskCache.entries[path] = ScanCacheEntry(
                    path:             path,
                    modificationDate: mtime,
                    libraryName:      core.libraryName,
                    libraryVersion:   core.libraryVersion,
                    validExtensions:  core.validExtensions,
                    needFullPath:     core.needFullPath
                )
                cacheModified = true
            }
        }

        if cacheModified { saveDiskCache(diskCache) }

        // ── Merge all results into in-memory store ─────────────────────────
        let allCores = cacheHits + probedResults.withLock({ $0 }).map { $0.1 }
        var newCores: [DiscoveredLibretroCore] = []

        for core in allCores {
            let id = core.syntheticIdentifier
            guard !knownIdentifiers.contains(id) else {
                DLOG("DynamicLibretroScanner: skipping known core \(id)")
                continue
            }
            let inserted = discoveredStorage.withLock { cache -> Bool in
                guard cache[id] == nil else { return false }
                cache[id] = core
                return true
            }
            if inserted {
                newCores.append(core)
                ILOG("DynamicLibretroScanner: discovered new core '\(core.libraryName)' v\(core.libraryVersion) → \(id)")
            }
        }

        ILOG("DynamicLibretroScanner: scan complete — \(newCores.count) new cores, \(cacheHits.count) from cache")
        return newCores
    }

    /// Clears the on-disk probe cache. Call when frameworks are updated or for debugging.
    public func clearDiskCache() {
        guard let url = Self.diskCacheURL else { return }
        try? FileManager.default.removeItem(at: url)
        ILOG("DynamicLibretroScanner: disk cache cleared")
    }

    /// Returns all previously-discovered cores (from the last `scan()` call).
    public var discoveredCores: [DiscoveredLibretroCore] {
        discoveredStorage.withLock { Array($0.values) }
    }

    /// Synthesises `EmulatorCoreInfoPlist` entries for all discovered cores so
    /// they can be merged into the main core-list alongside static plists.
    public func synthesisedCoreInfoPlist(
        systemsMappings: [String: [String]] = [:]
    ) -> EmulatorCoreInfoPlist? {
        let cores = discoveredCores
        guard !cores.isEmpty else { return nil }

        let subCores: [EmulatorCoreInfoPlist] = cores.map { core in
            let systems: [String] = core.validExtensions.flatMap { ext in
                systemsMappings[ext.lowercased()] ?? []
            }
            let uniqueSystems = Array(Set(systems)).sorted()

            return EmulatorCoreInfoPlist(
                identifier:        core.syntheticIdentifier,
                principleClass:    "PVThinLibretroFrontend",
                supportedSystems:  uniqueSystems,
                projectName:       core.libraryName,
                projectURL:        "",
                projectVersion:    core.libraryVersion,
                subCores:          nil
            )
        }

        return EmulatorCoreInfoPlist(
            identifier:       "com.provenance.thinlibretro",
            principleClass:   "PVThinLibretroFrontend",
            supportedSystems: [],
            projectName:      "Thin Libretro",
            projectURL:       "",
            projectVersion:   "1.0",
            subCores:         subCores
        )
    }

    // ---------------------------------------------------------------------------
    // MARK: - Private helpers
    // ---------------------------------------------------------------------------

    private func loadDiskCache() -> ScanCache {
        guard let url = Self.diskCacheURL,
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(ScanCache.self, from: data),
              cache.version == ScanCache.currentVersion else {
            return ScanCache()
        }
        DLOG("DynamicLibretroScanner: loaded disk cache (\(cache.entries.count) entries)")
        return cache
    }

    private func saveDiskCache(_ cache: ScanCache) {
        guard let url = Self.diskCacheURL else { return }
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
            DLOG("DynamicLibretroScanner: saved disk cache (\(cache.entries.count) entries)")
        } catch {
            WLOG("DynamicLibretroScanner: failed to save disk cache: \(error)")
        }
    }

    /// Collects all `.dylib` or `*.libretro.framework` executable URLs from
    /// the app bundle's `Frameworks/` directory.
    private func collectCandidateExecutables() -> [URL] {
        var candidates: [URL] = []
        let fm = FileManager.default

        let searchBases: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent("Frameworks"),
            Bundle.main.privateFrameworksURL,
        ].compactMap { $0 }

        for base in searchBases {
            guard fm.fileExists(atPath: base.path) else { continue }
            do {
                let contents = try fm.contentsOfDirectory(
                    at: base,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: .skipsHiddenFiles
                )
                for url in contents {
                    if url.pathExtension == "dylib" {
                        candidates.append(url)
                        continue
                    }
                    if url.pathExtension == "framework" {
                        let frameworkName = url.deletingPathExtension().lastPathComponent
                        if frameworkName.hasSuffix(".libretro") {
                            if let bundle = Bundle(url: url),
                               let exec = bundle.executableURL,
                               fm.fileExists(atPath: exec.path) {
                                candidates.append(exec)
                            } else {
                                let direct = url.appendingPathComponent(frameworkName)
                                if fm.fileExists(atPath: direct.path) {
                                    candidates.append(direct)
                                }
                            }
                        }
                    }
                }
            } catch {
                ELOG("DynamicLibretroScanner: error scanning \(base.path): \(error)")
            }
        }
        return candidates
    }

    /// Calls `retro_get_system_info` on a candidate dylib to extract metadata.
    /// Returns `nil` if the symbol is missing or dlopen fails.
    private func probe(executableURL: URL) -> DiscoveredLibretroCore? {
        #if !canImport(Darwin)
        return nil
        #else
        guard let handle = dlopen(executableURL.path, RTLD_LOCAL | RTLD_LAZY) else {
            DLOG("DynamicLibretroScanner: dlopen failed for \(executableURL.lastPathComponent): \(String(cString: dlerror()))")
            return nil
        }
        defer { dlclose(handle) }

        typealias GetSystemInfoFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
        guard let sym = dlsym(handle, "retro_get_system_info") else {
            DLOG("DynamicLibretroScanner: retro_get_system_info missing in \(executableURL.lastPathComponent)")
            return nil
        }

        let getInfo = unsafeBitCast(sym, to: GetSystemInfoFn.self)
        var raw = LibretroSystemInfo()
        withUnsafeMutablePointer(to: &raw) { ptr in
            getInfo(UnsafeMutableRawPointer(ptr))
        }

        guard let namePtr = raw.library_name else { return nil }
        let name    = String(cString: namePtr)
        let version = raw.library_version.map { String(cString: $0) } ?? ""
        let extList = raw.valid_extensions.map {
            String(cString: $0).split(separator: "|").map(String.init)
        } ?? []

        DLOG("DynamicLibretroScanner: probed \(executableURL.lastPathComponent) → '\(name)' v\(version)")

        return DiscoveredLibretroCore(
            executablePath:  executableURL,
            libraryName:     name,
            libraryVersion:  version,
            validExtensions: extList,
            needFullPath:    raw.need_fullpath
        )
        #endif
    }
}

// ---------------------------------------------------------------------------
// MARK: - CoreLoader integration
// ---------------------------------------------------------------------------

public extension CoreLoader {

    /// Injects dynamically-discovered libretro cores into the core-plist list.
    /// Call this after `getCorePlists()` to merge in thin-wrapper sub-cores.
    ///
    /// Guarded by the `dynamicLibretroScanner` feature flag (off by default).
    /// Enable for testing:
    /// ```
    /// UserDefaults.standard.set(true, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
    /// ```
    public static func mergeDiscoveredLibretroCores(
        into plists: [EmulatorCoreInfoPlist]
    ) -> [EmulatorCoreInfoPlist] {

        guard PVDynamicLibretroCoreScanner.isFeatureEnabled else {
            ILOG("DynamicLibretroScanner: disabled via feature flag — skipping scan")
            return plists
        }

        var knownIds: Set<String> = []
        for plist in plists {
            knownIds.insert(plist.identifier)
            plist.subCores?.forEach { knownIds.insert($0.identifier) }
        }

        let scanner = PVDynamicLibretroCoreScanner.shared
        scanner.scan(knownIdentifiers: knownIds)

        guard let syntheticParent = scanner.synthesisedCoreInfoPlist() else {
            ILOG("DynamicLibretroScanner: no new cores discovered — plist unchanged")
            return plists
        }

        let thinLibretroID = syntheticParent.identifier
        let deduplicated = plists.filter { $0.identifier != thinLibretroID }

        ILOG("DynamicLibretroScanner: merging \(syntheticParent.subCores?.count ?? 0) thin-wrapper sub-cores into plist")
        return deduplicated + [syntheticParent]
    }
}
