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
    static let currentVersion = 3   // bumped: tighter name/version heuristic rejects format strings
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

        let allCandidates = collectCandidateExecutables()
        ILOG("DynamicLibretroScanner: \(allCandidates.count) candidate executables found")
        guard !allCandidates.isEmpty else { return [] }

        /// Pre-filter: derive the synthetic identifier from the framework
        /// directory name and skip candidates already covered by static plists.
        /// The framework dirname (e.g. "scummvm.libretro.framework") matches the
        /// identifier format used in PVRetroArch/Core.plist sub-cores.
        let candidates = allCandidates.filter { url in
            let id = Self.syntheticIdentifier(fromExecutableURL: url)
            if knownIdentifiers.contains(id) {
                DLOG("DynamicLibretroScanner: skipping known core \(id) (pre-filter)")
                return false
            }
            return true
        }

        let skippedCount = allCandidates.count - candidates.count
        ILOG("DynamicLibretroScanner: \(skippedCount) already known, \(candidates.count) need probing")
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
        let probedResults = OSAllocatedUnfairLock<[(URL, DiscoveredLibretroCore)]>(initialState: [])

        if !cacheMisses.isEmpty {
            let total = candidates.count
            let completedCount = OSAllocatedUnfairLock<Int>(initialState: cacheHits.count)

            if let onProgress, !cacheHits.isEmpty {
                onProgress(cacheHits.count, total, "")
            }

            let probeQueue = DispatchQueue(label: "com.provenance.libretro-probe",
                                           qos: .background,
                                           attributes: .concurrent)
            let group = DispatchGroup()
            for i in 0..<cacheMisses.count {
                group.enter()
                probeQueue.async {
                    defer { group.leave() }
                    let url = cacheMisses[i]
                    let coreName = url.deletingLastPathComponent().lastPathComponent
                    let core = self.probeMachO(executableURL: url) ?? self.probe(executableURL: url)
                    if let core = core {
                        probedResults.withLock { $0.append((url, core)) }
                    }
                    let n = completedCount.withLock { count -> Int in count += 1; return count }
                    onProgress?(n, total, core?.libraryName ?? coreName)
                }
            }
            group.wait()

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

        // ── Merge results into in-memory store ────────────────────────────
        let allCores = cacheHits + probedResults.withLock({ $0 }).map { $0.1 }
        var newCores: [DiscoveredLibretroCore] = []

        for core in allCores {
            let id = core.syntheticIdentifier
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

        ILOG("DynamicLibretroScanner: scan complete — \(newCores.count) new cores")
        return newCores
    }

    /// Derives a synthetic identifier from an executable's path without probing.
    ///
    /// For framework executables the parent dir IS the identifier:
    ///   `Frameworks/scummvm.libretro.framework/scummvm.libretro` → `"scummvm.libretro.framework"`
    /// For bare dylibs, constructs an identifier from the filename:
    ///   `Frameworks/mgba_libretro_ios.dylib` → `"mgba_libretro_ios.libretro.framework"`
    static func syntheticIdentifier(fromExecutableURL url: URL) -> String {
        let parentDir = url.deletingLastPathComponent().lastPathComponent
        if parentDir.hasSuffix(".framework") {
            return parentDir
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return "\(stem).libretro.framework"
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
                principleClass:    "PVThinLibretroCore",
                supportedSystems:  uniqueSystems,
                projectName:       core.libraryName,
                projectURL:        "",
                projectVersion:    core.libraryVersion,
                subCores:          nil
            )
        }

        return EmulatorCoreInfoPlist(
            identifier:       "com.provenance.thinlibretro",
            principleClass:   "PVThinLibretroCore",
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

    /// Collects libretro executable URLs from the app bundle's `Frameworks/` directory.
    ///
    /// Only considers `.dylib` files containing "libretro" in their name and
    /// `*.libretro.framework` bundles. Search paths are deduplicated to avoid
    /// scanning the same directory twice (iOS's `privateFrameworksURL` is `Frameworks/`).
    private func collectCandidateExecutables() -> [URL] {
        var candidates: [URL] = []
        let fm = FileManager.default

        /// Deduplicate search paths — on iOS both resolve to the same Frameworks/ dir
        let searchBases: [URL] = Array(Set([
            Bundle.main.bundleURL.appendingPathComponent("Frameworks"),
            Bundle.main.privateFrameworksURL,
        ].compactMap { $0?.standardizedFileURL }))

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
                        let name = url.deletingPathExtension().lastPathComponent
                        guard name.contains("libretro") else { continue }
                        candidates.append(url)
                        continue
                    }
                    if url.pathExtension == "framework" {
                        let frameworkName = url.deletingPathExtension().lastPathComponent
                        guard frameworkName.hasSuffix(".libretro") else { continue }
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
            } catch {
                ELOG("DynamicLibretroScanner: error scanning \(base.path): \(error)")
            }
        }
        return candidates
    }

    /// Fast-path: parse the Mach-O `__TEXT,__cstring` section to extract
    /// `retro_get_system_info` metadata without calling `dlopen`.
    ///
    /// Saves the ~1 s code-signing overhead on first encounter of a new core.
    /// Returns `nil` when parsing fails; the caller then falls back to `probe()`.
    private func probeMachO(executableURL: URL) -> DiscoveredLibretroCore? {
        #if !canImport(Darwin)
        return nil
        #else
        guard let fileData = try? Data(contentsOf: executableURL, options: .mappedIfSafe) else { return nil }

        return fileData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> DiscoveredLibretroCore? in
            guard let base = raw.baseAddress,
                  raw.count > MemoryLayout<mach_header_64>.size else { return nil }

            // ── Locate native-arch Mach-O slice (handles fat binaries) ────────────
            var hdrOffset = 0
            let magic = base.load(as: UInt32.self)
            if magic == 0xcafebabe || magic == 0xbebafeca {
                // Fat binary — scan arch entries for arm64 (CPU_TYPE_ARM64 = 0x0100000c)
                let swap = magic == 0xbebafeca
                let nfat = Int(machoU32(base.advanced(by: 4), swap: swap))
                for i in 0..<nfat {
                    let aBase = base.advanced(by: 8 + i * 20)
                    guard 8 + (i + 1) * 20 <= raw.count else { break }
                    if machoU32(aBase, swap: swap) == 0x0100000c {
                        hdrOffset = Int(machoU32(aBase.advanced(by: 8), swap: swap))
                        break
                    }
                }
            }
            guard hdrOffset + MemoryLayout<mach_header_64>.size <= raw.count else { return nil }
            let hdr = base.advanced(by: hdrOffset).assumingMemoryBound(to: mach_header_64.self).pointee
            guard hdr.magic == MH_MAGIC_64 else { return nil }

            // ── Walk load commands to find __TEXT,__cstring ───────────────────────
            var cstringStart = 0; var cstringLen = 0
            var lcOff = hdrOffset + MemoryLayout<mach_header_64>.size

            outerLoop: for _ in 0..<Int(hdr.ncmds) {
                guard lcOff + MemoryLayout<load_command>.size <= raw.count else { break }
                let lc = base.advanced(by: lcOff).assumingMemoryBound(to: load_command.self).pointee
                let cmdSize = Int(lc.cmdsize)
                guard cmdSize > 0, lcOff + cmdSize <= raw.count else { break }

                if lc.cmd == UInt32(LC_SEGMENT_64),
                   cmdSize >= MemoryLayout<segment_command_64>.size {
                    let seg = base.advanced(by: lcOff)
                        .assumingMemoryBound(to: segment_command_64.self).pointee
                    if machoSegName(seg.segname) == "__TEXT" {
                        let sectBase = lcOff + MemoryLayout<segment_command_64>.size
                        for s in 0..<Int(seg.nsects) {
                            let sOff = sectBase + s * MemoryLayout<section_64>.size
                            guard sOff + MemoryLayout<section_64>.size <= raw.count else { break }
                            let sect = base.advanced(by: sOff)
                                .assumingMemoryBound(to: section_64.self).pointee
                            if machoSegName(sect.sectname) == "__cstring" {
                                cstringStart = Int(sect.offset)
                                cstringLen   = Int(sect.size)
                                break outerLoop
                            }
                        }
                        break outerLoop
                    }
                }
                lcOff += cmdSize
            }
            guard cstringLen > 0, cstringStart > 0,
                  cstringStart + cstringLen <= raw.count else { return nil }

            // ── Collect all C strings from __cstring ──────────────────────────────
            var strings: [String] = []
            var pos = cstringStart
            let end = cstringStart + cstringLen
            while pos < end {
                let cptr = base.advanced(by: pos).assumingMemoryBound(to: CChar.self)
                var len = 0
                while pos + len < end && cptr[len] != 0 { len += 1 }
                if len > 0 {
                    if let s = String(
                        bytes: UnsafeRawBufferPointer(start: UnsafeRawPointer(cptr), count: len),
                        encoding: .utf8
                    ) { strings.append(s) }
                }
                pos += len + 1
            }

            // ── Identify valid_extensions (pipe-separated short file extensions) ──
            // Pattern: "gb|gbc|dmg" or "zip|7z|rar" — at least two alternatives
            let extRegex = try? NSRegularExpression(pattern: #"^[a-zA-Z0-9]{1,8}(\|[a-zA-Z0-9]{1,8})+$"#)
            guard let extIdx = strings.firstIndex(where: { s in
                let r = NSRange(s.startIndex..., in: s)
                return extRegex?.firstMatch(in: s, range: r) != nil
            }) else { return nil }

            let extStr = strings[extIdx]
            let exts   = extStr.split(separator: "|").map(String.init)

            // ── Find library_name and library_version near the extensions string ──
            // In most libretro cores the three strings appear close together
            // in __cstring because retro_get_system_info is defined near the top.
            let lo     = max(0, extIdx - 6)
            let hi     = min(strings.count - 1, extIdx + 6)
            let window = strings[lo...hi].filter { $0 != extStr }

            // Reject strings that look like C format specifiers, file extensions,
            // file paths, or other non-name metadata that can appear in __cstring.
            let looksLikeJunk: (String) -> Bool = { s in
                s.contains("%") ||                       // printf format string ("%d.mcr", "%*lld")
                s.hasPrefix(".") ||                      // file extension (".mv", ".srm")
                s.hasPrefix("/") ||                      // file path
                s.hasPrefix("\\") ||                     // Windows path
                s.contains("\t") ||                      // tab-separated data
                s.unicodeScalars.contains(where: { $0.value < 0x20 }) // control chars
            }

            // library_name: readable human name (starts with a letter, has >= 2 letters,
            // no pipe, 2–60 chars, no format specifiers or file-extension patterns)
            let libraryName = window.first(where: { s in
                !s.contains("|") && s.count >= 2 && s.count <= 60 &&
                !looksLikeJunk(s) &&
                s.first?.isLetter == true &&
                s.filter({ $0.isLetter }).count >= 2
            })
            guard let libName = libraryName else { return nil }

            // library_version: prefer strings with at least one letter; skip pure date strings
            // (e.g. "2024.10.29" is a build date in many buildbot cores, not the real version tag).
            let dateRegex = try? NSRegularExpression(pattern: #"^\d{4}[.\-]\d{2}[.\-]\d{2}$"#)
            let isDate: (String) -> Bool = { s in
                let r = NSRange(s.startIndex..., in: s)
                return dateRegex?.firstMatch(in: s, range: r) != nil
            }
            let libVersion = window.first(where: { s in
                s != libName && !isDate(s) && !looksLikeJunk(s) &&
                s.count >= 1 && s.count <= 30 &&
                s.range(of: "[A-Za-z]", options: .regularExpression) != nil
            }) ?? window.first(where: { s in
                s != libName && !isDate(s) && !looksLikeJunk(s) &&
                s.count >= 1 && s.count <= 30
            }) ?? ""

            DLOG("DynamicLibretroScanner: probeMachO '\(executableURL.lastPathComponent)' → '\(libName)' v\(libVersion)")
            return DiscoveredLibretroCore(
                executablePath:  executableURL,
                libraryName:     libName,
                libraryVersion:  libVersion,
                validExtensions: exts,
                needFullPath:    false   // conservative; probe() corrects if needed
            )
        }
        #endif
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
        into plists: [EmulatorCoreInfoPlist],
        onProgress: (@Sendable (_ completed: Int, _ total: Int, _ currentName: String) -> Void)? = nil
    ) -> [EmulatorCoreInfoPlist] {

        var knownIds: Set<String> = []
        for plist in plists {
            knownIds.insert(plist.identifier)
            plist.subCores?.forEach { knownIds.insert($0.identifier) }
        }

        #if DEBUG
        diagnosOrphanCores(knownIdentifiers: knownIds)
        diagnoseMissingCoreFrameworks(plists: plists)
        #endif

        guard PVDynamicLibretroCoreScanner.isFeatureEnabled else {
            ILOG("DynamicLibretroScanner: disabled via feature flag — skipping scan")
            return plists
        }

        let scanner = PVDynamicLibretroCoreScanner.shared
        scanner.scan(knownIdentifiers: knownIds, onProgress: onProgress)

        guard let syntheticParent = scanner.synthesisedCoreInfoPlist() else {
            ILOG("DynamicLibretroScanner: no new cores discovered — plist unchanged")
            return plists
        }

        let thinLibretroID = syntheticParent.identifier
        let deduplicated = plists.filter { $0.identifier != thinLibretroID }

        ILOG("DynamicLibretroScanner: merging \(syntheticParent.subCores?.count ?? 0) thin-wrapper sub-cores into plist")
        return deduplicated + [syntheticParent]
    }

    #if DEBUG
    /// Logs libretro frameworks in the bundle that aren't mapped to any system,
    /// indicating wasted bundle size. Only runs in DEBUG builds.
    internal static func diagnosOrphanCores(knownIdentifiers: Set<String>) {
        let fm = FileManager.default
        let frameworksURL = Bundle.main.bundleURL.appendingPathComponent("Frameworks")
        guard fm.fileExists(atPath: frameworksURL.path) else { return }

        guard let contents = try? fm.contentsOfDirectory(
            at: frameworksURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        let libretroFrameworks = contents.filter {
            $0.pathExtension == "framework" &&
            $0.deletingPathExtension().lastPathComponent.hasSuffix(".libretro")
        }

        let orphans = libretroFrameworks.filter { url in
            /// Framework dirname IS the identifier (e.g. "scummvm.libretro.framework")
            !knownIdentifiers.contains(url.lastPathComponent)
        }

        if !orphans.isEmpty {
            let names = orphans.map { $0.deletingPathExtension().lastPathComponent }
            WLOG("DynamicLibretroScanner: \(orphans.count) orphan libretro framework(s) not mapped to any system: \(names)")
            assertionFailure("Orphan libretro cores found in bundle — these add to app size but serve no purpose: \(names)")
        }
    }

    /// Logs sub-cores declared in plists that are enabled but missing their
    /// framework from the bundle — meaning the user sees a core option thatse    /// will fail at runtime. Catches build script omissions early.
    internal static func diagnoseMissingCoreFrameworks(plists: [EmulatorCoreInfoPlist]) {
        let fm = FileManager.default
        let frameworksURL = Bundle.main.bundleURL.appendingPathComponent("Frameworks")

        let isAppStore = Bundle.main.infoDictionary?["PVAppType"] as? String ?? ""
        let appStoreMode = isAppStore.lowercased().contains("appstore")

        var missing: [String] = []

        for plist in plists {
            for subCore in plist.subCores ?? [] {
                guard !subCore.disabled else { continue }
                if appStoreMode && subCore.appStoreDisabled { continue }
                guard subCore.identifier.contains(".libretro") else { continue }

                /// The identifier IS the framework dirname (e.g. "scummvm.libretro.framework")
                let frameworkDir = frameworksURL.appendingPathComponent(subCore.identifier)
                if !fm.fileExists(atPath: frameworkDir.path) {
                    missing.append(subCore.identifier)
                }
            }
        }

        if !missing.isEmpty {
            WLOG("CoreLoader: \(missing.count) enabled sub-core(s) missing their framework from bundle: \(missing)")
            assertionFailure("Enabled libretro sub-cores missing from Frameworks/ — build scripts may have missed them: \(missing)")
        } else {
            ILOG("CoreLoader: all enabled libretro sub-cores have matching frameworks in bundle")
        }
    }
    #endif
}

// ---------------------------------------------------------------------------
// MARK: - Mach-O decoding helpers (file-private)
// ---------------------------------------------------------------------------

/// Read a `UInt32` from a raw pointer, optionally byte-swapping (for fat binary headers).
private func machoU32(_ ptr: UnsafeRawPointer, swap: Bool) -> UInt32 {
    let v = ptr.load(as: UInt32.self)
    return swap ? v.byteSwapped : v
}

/// Extract a null-terminated segment/section name from a fixed 16-byte C char tuple.
/// Uses a generic binding so swiftlint's large_tuple rule isn't triggered.
private func machoSegName<T>(_ tuple: T) -> String {
    withUnsafeBytes(of: tuple) { bytes in
        let chars = bytes.prefix(while: { $0 != 0 })
        return String(bytes: chars, encoding: .utf8) ?? ""
    }
}
