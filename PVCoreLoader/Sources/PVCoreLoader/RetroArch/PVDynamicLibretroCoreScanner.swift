//
//  PVDynamicLibretroCoreScanner.swift
//  PVCoreLoader
//
//  Created by Claude (Agent) on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Scans the app's Frameworks directory at boot time for bare libretro
//  dylibs (`.dylib` or `.libretro.framework`) that are NOT already
//  represented by a static PVRetroArch sub-core plist entry.
//
//  Discovered cores are registered as synthetic sub-cores of the
//  "PVThinLibretro" virtual parent core, which maps them into the
//  normal Provenance core-selection UI.
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
    ///    (accessible on all build types; hidden behind cheat code on App Store).
    /// 2. A direct UserDefaults boolean under `featureFlagKey` — for scripted or
    ///    launch-argument overrides: `UserDefaults.standard.set(true, forKey: ...)`.
    ///
    /// **Off by default** — enable to test buildbot-style libretro cores.
    public static var isFeatureEnabled: Bool {
        // Check the PVFeatureFlags debug-override dict first (feature flag UI path).
        // Stored as [String: Any] under "PVFeatureFlagsDebugOverrides".
        // PVFeatureFlags uses the string sentinel "nil" to represent a cleared override
        // (i.e. "no override set"); in that case we fall through to the direct key check.
        if let overrides = UserDefaults.standard.dictionary(forKey: "PVFeatureFlagsDebugOverrides") {
            let entry = overrides[featureFlagKey]
            if let boolValue = entry as? Bool {
                return boolValue   // explicit true/false override
            }
            if (entry as? String) == "nil" {
                // "nil" sentinel means the override was explicitly cleared — ignore it
                // and fall through to the direct UserDefaults key below.
            } else if entry != nil {
                // Unknown type stored under this key — treat as no override.
            }
        }
        // Fall back to a direct UserDefaults boolean (scripted / launch-arg override).
        return UserDefaults.standard.bool(forKey: featureFlagKey)
    }

    // Thread-safe cache: identifier → DiscoveredLibretroCore
    private let discoveredStorage = OSAllocatedUnfairLock<[String: DiscoveredLibretroCore]>(initialState: [:])

    // Tracks the set of paths already probed so repeat scan() calls skip them.
    private let probedPaths = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    // ---------------------------------------------------------------------------
    // MARK: - Scan
    // ---------------------------------------------------------------------------

    /// Scans the app bundle's `Frameworks/` directory and private frameworks directory
    /// for libretro dylibs that are NOT already listed in `knownIdentifiers`.
    ///
    /// Calls `retro_get_system_info` via `dlopen`/`dlsym` for each candidate.
    /// Results are cached; subsequent calls with the same known set are cheap.
    ///
    /// - Parameter knownIdentifiers: Set of core identifiers already registered
    ///   via static plists (e.g. all PVRetroArch sub-core identifiers). These are
    ///   skipped — we don't duplicate what's already known.
    /// - Returns: Array of `DiscoveredLibretroCore` values for newly found cores.
    @discardableResult
    public func scan(knownIdentifiers: Set<String> = []) -> [DiscoveredLibretroCore] {
        ILOG("DynamicLibretroScanner: starting scan (knownIdentifiers: \(knownIdentifiers.count))")

        let candidates = collectCandidateExecutables()
        ILOG("DynamicLibretroScanner: \(candidates.count) candidate dylib/framework paths found")

        // Filter already-probed paths before the concurrent dlopen step.
        let unprobed = candidates.filter { url in
            !probedPaths.withLock { $0.contains(url.path) }
        }

        guard !unprobed.isEmpty else {
            ILOG("DynamicLibretroScanner: all candidates already probed — scan complete (0 new)")
            return []
        }

        ILOG("DynamicLibretroScanner: probing \(unprobed.count) new candidates concurrently")

        // dlopen/dlclose are thread-safe on Darwin; probe all candidates in parallel.
        let probedResults = OSAllocatedUnfairLock<[DiscoveredLibretroCore]>(initialState: [])

        DispatchQueue.concurrentPerform(iterations: unprobed.count) { i in
            let url = unprobed[i]
            defer { probedPaths.withLock { $0.insert(url.path) } }

            guard let core = probe(executableURL: url) else { return }

            let id = core.syntheticIdentifier
            guard !knownIdentifiers.contains(id) else {
                DLOG("DynamicLibretroScanner: skipping known core \(id)")
                return
            }
            probedResults.withLock { $0.append(core) }
        }

        // Merge into the persistent cache and collect truly new cores.
        var newCores: [DiscoveredLibretroCore] = []
        for core in probedResults.withLock({ $0 }) {
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

        ILOG("DynamicLibretroScanner: scan complete — \(newCores.count) new cores found")
        return newCores
    }

    /// Returns all previously-discovered cores (from the last `scan()` call).
    public var discoveredCores: [DiscoveredLibretroCore] {
        discoveredStorage.withLock { Array($0.values) }
    }

    /// Synthesises `EmulatorCoreInfoPlist` entries for all discovered cores so
    /// they can be merged into the main core-list alongside static plists.
    ///
    /// Each discovered core becomes a sub-core of the "PVThinLibretro" parent,
    /// using the same identifier convention as PVRetroArch sub-cores.
    ///
    /// - Parameter systemsMappings: Optional dictionary mapping known
    ///   extension → system identifier for richer plist generation.
    /// - Returns: A synthetic parent plist containing all discovered sub-cores.
    public func synthesisedCoreInfoPlist(
        systemsMappings: [String: [String]] = [:]
    ) -> EmulatorCoreInfoPlist? {
        let cores = discoveredCores
        guard !cores.isEmpty else { return nil }

        let subCores: [EmulatorCoreInfoPlist] = cores.map { core in
            // Derive supported systems from valid_extensions using the mapping table,
            // or leave empty so the user picks the system manually.
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

    /// Collects all `.dylib` or `*.libretro` framework executable URLs in the
    /// app bundle's `Frameworks/` directory.
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
                    // Bare dylib: e.g. mgba.dylib
                    if url.pathExtension == "dylib" {
                        candidates.append(url)
                        continue
                    }

                    // Framework whose name ends in ".libretro":
                    // e.g. mgba.libretro.framework/mgba.libretro
                    if url.pathExtension == "framework" {
                        let frameworkName = url.deletingPathExtension().lastPathComponent
                        if frameworkName.hasSuffix(".libretro") {
                            // Try Bundle lookup first, then direct path
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
        // Reuse the module-internal LibretroSystemInfo (defined in LibretroMetadataReader.swift)
        // so both readers share a single layout definition that can't drift out of sync.
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
    /// The scan is guarded by the `dynamicLibretroScanner` feature flag (off by default).
    /// Enable it for testing via:
    /// ```
    /// UserDefaults.standard.set(true, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
    /// ```
    ///
    /// - Parameter plists: The existing static plist array.
    /// - Returns: Updated array that includes a synthetic "Thin Libretro" parent
    ///            containing all newly-discovered dylib cores, or the original array
    ///            unchanged if the feature flag is disabled.
    public static func mergeDiscoveredLibretroCores(
        into plists: [EmulatorCoreInfoPlist]
    ) -> [EmulatorCoreInfoPlist] {

        guard PVDynamicLibretroCoreScanner.isFeatureEnabled else {
            ILOG("DynamicLibretroScanner: disabled via feature flag — skipping scan (set '\(PVDynamicLibretroCoreScanner.featureFlagKey)' in UserDefaults to enable)")
            return plists
        }

        // Collect identifiers that are already registered
        var knownIds: Set<String> = []
        for plist in plists {
            knownIds.insert(plist.identifier)
            if let subCores = plist.subCores {
                for sub in subCores { knownIds.insert(sub.identifier) }
            }
        }

        let scanner = PVDynamicLibretroCoreScanner.shared
        scanner.scan(knownIdentifiers: knownIds)

        guard let syntheticParent = scanner.synthesisedCoreInfoPlist() else {
            ILOG("DynamicLibretroScanner: no new cores discovered — plist unchanged")
            return plists
        }

        // Remove any previous synthetic parent so repeated calls don't duplicate it.
        let thinLibretroID = syntheticParent.identifier
        let deduplicated = plists.filter { $0.identifier != thinLibretroID }

        ILOG("DynamicLibretroScanner: merging \(syntheticParent.subCores?.count ?? 0) thin-wrapper sub-cores into plist")
        return deduplicated + [syntheticParent]
    }
}
