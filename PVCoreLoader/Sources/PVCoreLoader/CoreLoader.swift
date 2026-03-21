//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  GameImporter.swift
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import Foundation
import os
import PVSupport
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import SwiftMacros
import PVPlists

public enum CoreLoaderError: Error {
    case systemsDotPlistNotFound
    case noCoresFound
}

public final class CoreLoader: Sendable {

    public static let shared: CoreLoader = .init()
    private init() {}

    fileprivate let ThisBundle: Bundle = Bundle.module

    /// Thread-safe storage wrapping the cached core plists array.
    /// `OSAllocatedUnfairLock` eliminates bare lock/unlock pairs and the associated
    /// early-return deadlock risk present with `NSLock`.
    private static let cacheStorage = OSAllocatedUnfairLock<[EmulatorCoreInfoPlist]?>(initialState: nil)

    /// Clears the cached core plists, forcing a reload on next getCorePlists() call
    /// This is primarily useful for testing or in rare cases where cores might change during runtime
    static public func clearCoreListCache() {
        cacheStorage.withLock { $0 = nil }
        ILOG("Core plists cache cleared")
    }

//    public func parseCoresPlists(plists: [URL]) async -> [EmulatorCoreInfoPlist] {
//        // Loading cores and calling `.corePlist` property on the `Class.self`
//        let corePlistsStructs = plists.compactMap {
//            do {
//                return try EmulatorCoreInfoPlist(fromURL: $0)
//            } catch {
//                ELOG("\(error.localizedDescription) for URL: \($0.debugDescription)")
//            }
//            return nil
//        }
//        return corePlistsStructs
//    }

    static public func getCorePlists() -> [EmulatorCoreInfoPlist] {
        /// Fast path: return cached value without doing I/O
        if let cached = cacheStorage.withLock({ $0 }) {
            DLOG("Returning cached core plists (\(cached.count) items)")
            return cached
        }

        /// Load outside the lock so we don't block other threads during filesystem I/O
        ILOG("Loading core plists from file system...")
        let plists = loadCorePlists()

        /// Store result — concurrent first-load races are benign (last writer wins)
        cacheStorage.withLock { $0 = plists }

        /// Populate the JIT requirement registry from each loaded plist.
        /// This is the single place where Core.plist JIT data flows into the registry —
        /// no hardcoded identifier list is needed anywhere else.
        registerJITRequirements(from: plists)

        ILOG("Cached \(plists.count) core plists for future use")
        return plists
    }

    /// Reads `PVJITRequirement` from each plist and registers it in the shared registry.
    /// The registry is cleared first so that entries for cores that are no longer present
    /// in the active core list do not remain stale.
    static private func registerJITRequirements(from plists: [EmulatorCoreInfoPlist]) {
        let registry = PVJITRequirementRegistry.shared
        registry.reset()
        for plist in plists {
            if let raw = plist.jitRequirementRawValue {
                registry.register(rawValue: raw, forCoreIdentifier: plist.identifier)
            }
            if plist.jitDisabledWithoutJIT {
                registry.registerJITDisabled(forCoreIdentifier: plist.identifier)
            }
            // Also handle sub-cores (e.g. libretro cores embedded in RetroArch's plist)
            for subCore in plist.subCores ?? [] {
                if let raw = subCore.jitRequirementRawValue {
                    registry.register(rawValue: raw, forCoreIdentifier: subCore.identifier)
                }
                if subCore.jitDisabledWithoutJIT {
                    registry.registerJITDisabled(forCoreIdentifier: subCore.identifier)
                }
            }
        }
    }

    /// Returns identifiers of cores that are currently disabled solely because JIT is required.
    ///
    /// Call this after JIT is acquired to find cores that should be auto-enabled.
    /// Part of the smart JIT acquisition flow (#2794).
    public static func jitDisabledCoreIdentifiers() -> [String] {
        PVJITRequirementRegistry.shared.jitDisabledCoreIdentifiers()
    }

    /// Internal method that actually loads the core plists
    static private func loadCorePlists() -> [EmulatorCoreInfoPlist] {
//        if #available(iOS 17, *) {
//            return getCorePlistsFromDyload()
//        } else {
            let plists = getCorePlistsFromFileSystem()
            return applyRuntimeMetadataOverrides(on: plists)
//        }
    }

    static private func getCorePlistsFromDyload() -> [EmulatorCoreInfoPlist] {
        // Scan all subclasses of PVEmulator core, and get their metadata
        // like their subclass name and the bundle they belong to
        let coreClasses: [ClassInfo] = CoreClasses.coreClasses

        let plists: [EmulatorCoreInfoPlist] = coreClasses.map { classInfo in
            let plist: EmulatorCoreInfoPlist = classInfo.classObject.corePlist
            return plist
        }

        return plists
    }

    static private func getCorePlistsFromFileSystem() -> [EmulatorCoreInfoPlist] {
        var plists: [EmulatorCoreInfoPlist] = []

        // Get main bundle path
        let mainBundlePath = Bundle.main.bundleURL

        // Get Frameworks directory path
        let frameworksPath = mainBundlePath.appendingPathComponent("Frameworks")

        // Define paths to scan
        let pathsToScan = [mainBundlePath, frameworksPath]

        do {
            // Scan each path for both .framework and .bundle
            for path in pathsToScan {
                // Skip if directory doesn't exist
                guard FileManager.default.fileExists(atPath: path.path) else { continue }

                let contents = try FileManager.default.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                // Filter for bundles and frameworks
                let bundlePaths = contents.filter { url in
                    let pathExtension = url.pathExtension.lowercased()
                    return pathExtension == "framework" || pathExtension == "bundle"
                }

                // Load Core.plist from each bundle
                for bundlePath in bundlePaths {
                    if let plist = try loadCorePlist(from: bundlePath) {
                        plists.append(plist)
                        ILOG("Loaded Core.plist from \(bundlePath.lastPathComponent)")
                    }
                }
            }

            // Also check main bundle itself for Core.plist
            if let mainBundlePlist = try loadCorePlist(from: mainBundlePath) {
                plists.append(mainBundlePlist)
                ILOG("Loaded Core.plist from main bundle")
            }

        } catch {
            ELOG("Error scanning for Core.plists: \(error)")
        }

        return plists
    }

    static private func applyRuntimeMetadataOverrides(on plists: [EmulatorCoreInfoPlist]) -> [EmulatorCoreInfoPlist] {
        ILOG("RetroArch metadata: Applying runtime metadata overrides to \(plists.count) core plists")
        var updatedCount = 0
        var libretroCount = 0

        let result = plists.map { plist -> EmulatorCoreInfoPlist in
            /// Check if this plist has subCores (like PVRetroArch which contains all libretro cores)
            if let subCores = plist.subCores, !subCores.isEmpty {
                ILOG("RetroArch metadata: Processing \(subCores.count) sub-cores for \(plist.identifier)")
                let updatedSubCores = subCores.map { subCore -> EmulatorCoreInfoPlist in
                    /// Only process libretro sub-cores that have ".libretro.framework" in their identifier
                    guard subCore.identifier.contains(".libretro.framework") else {
                        return subCore
                    }

                    libretroCount += 1

                    guard let metadata = LibretroMetadataReader.metadata(forIdentifier: subCore.identifier),
                          !metadata.version.isEmpty else {
                        DLOG("RetroArch metadata: No runtime metadata for \(subCore.identifier), using plist version: \(subCore.projectVersion)")
                        return subCore
                    }

                    if metadata.version == subCore.projectVersion {
                        DLOG("RetroArch metadata: Version unchanged for \(subCore.identifier): \(metadata.version)")
                        return subCore
                    }

                    ILOG("RetroArch metadata: Updating \(subCore.identifier) version '\(subCore.projectVersion)' -> '\(metadata.version)'")
                    updatedCount += 1
                    return subCore.updating(projectVersion: metadata.version)
                }

                /// Return parent plist with updated subCores
                return plist.updating(subCores: updatedSubCores)
            }

            /// Also check top-level plists for .libretro.framework pattern (in case they're not nested)
            guard plist.identifier.contains(".libretro.framework") else {
                return plist
            }

            libretroCount += 1

            guard let metadata = LibretroMetadataReader.metadata(forIdentifier: plist.identifier),
                  !metadata.version.isEmpty else {
                DLOG("RetroArch metadata: No runtime metadata for \(plist.identifier), using plist version: \(plist.projectVersion)")
                return plist
            }

            if metadata.version == plist.projectVersion {
                DLOG("RetroArch metadata: Version unchanged for \(plist.identifier): \(metadata.version)")
                return plist
            }

            ILOG("RetroArch metadata: Updating \(plist.identifier) version '\(plist.projectVersion)' -> '\(metadata.version)'")
            updatedCount += 1
            return plist.updating(projectVersion: metadata.version)
        }

        ILOG("RetroArch metadata: Complete - found \(libretroCount) libretro cores, updated \(updatedCount) versions")
        return result
    }

    static private func loadCorePlist(from bundlePath: URL) throws -> EmulatorCoreInfoPlist? {
        let plistPath = bundlePath.appendingPathComponent("Core.plist")

        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            return nil
        }

        do {
            let plist = try EmulatorCoreInfoPlist(fromURL: plistPath)
            ILOG("Successfully loaded Core.plist from \(bundlePath.lastPathComponent)")
            return plist
        } catch {
            ELOG("Failed to load Core.plist from \(bundlePath.lastPathComponent): \(error)")
            return nil
        }
    }

//    public func parseSystemsPlist() throws(CoreLoaderError) -> [URL] {
//        guard let systemsPlist = ThisBundle.url(forResource: "systems", withExtension: "plist") else {
//            assertionFailure("Missing systems.plist")
//            throw CoreLoaderError.systemsDotPlistNotFound
//        }
//
//        return [systemsPlist]
//    }

    static public func systemsPlist() ->  [[String: Any]] {
        return PlistFiles.items
    }
}

private extension EmulatorCoreInfoPlist {
    func updating(projectVersion: String? = nil, subCores: [EmulatorCoreInfoPlist]? = nil) -> EmulatorCoreInfoPlist {
        return EmulatorCoreInfoPlist(
            identifier: identifier,
            principleClass: principleClass,
            supportedSystems: supportedSystems,
            projectName: projectName,
            projectURL: projectURL,
            projectVersion: projectVersion ?? self.projectVersion,
            disabled: disabled,
            contentless: contentless,
            appStoreDisabled: appStoreDisabled,
            supportedCheatTypes: supportedCheatTypes,
            subCores: subCores ?? self.subCores,
            jitRequirementRawValue: jitRequirementRawValue,
            jitDisabledWithoutJIT: jitDisabledWithoutJIT,
            licenseName: licenseName,
            licenseURL: licenseURL,
            copyright: copyright,
            capabilities: capabilities
        )
    }
}
