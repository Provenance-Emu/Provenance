//
//  GameImporterSystemsService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/7/24.
//

import Foundation
import os
import PVLookup
import PVSystems
import PVPrimitives

public protocol SkinImporterServicing {
    func importSkin(from url: URL) async throws
}

public protocol GameImporterSystemsServicing {
    /// The type of game this service works with
    typealias GameType = PVGame

    /// Find any existing games that could belong to the given systems with the specified ROM filename
    func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem], romFilename: String) -> [GameType]?

    /// Determine which systems can handle this import item
    func determineSystems(for item: ImportQueueItem) async throws -> [SystemIdentifier]
}

class GameImporterSystemsService: GameImporterSystemsServicing {
    private let lookup: PVLookup
    /// Thread-safe guard for `systemsCache`. Uses `OSAllocatedUnfairLock` (iOS 16+).
    private let cacheLock = OSAllocatedUnfairLock<Void>()

    private struct SystemsCacheEntry<Value> {
        var value: Value?
        var lastAccess: TimeInterval
    }

    private enum SystemsCacheResult<Value> {
        case hit(Value)
        case miss
    }

    private struct SystemCacheKey: Hashable {
        let filename: String
        let fileExtension: String
        let parentDirectory: String
    }

    private var systemsCache: [SystemCacheKey: SystemsCacheEntry<[SystemIdentifier]>] = [:]
    private let systemsCacheLimit = 1024

    init(lookup: PVLookup = .shared) {
        self.lookup = lookup
    }

    private func cachedSystems(for key: SystemCacheKey) -> SystemsCacheResult<[SystemIdentifier]>? {
        cacheLock.withLock {
            guard var entry = systemsCache[key] else { return nil }
            entry.lastAccess = Date().timeIntervalSinceReferenceDate
            systemsCache[key] = entry
            if let value = entry.value {
                return .hit(value)
            } else {
                return .miss
            }
        }
    }

    private func cacheSystems(_ value: [SystemIdentifier]?, for key: SystemCacheKey) {
        let shouldTrim = cacheLock.withLock { () -> Bool in
            systemsCache[key] = SystemsCacheEntry(value: value, lastAccess: Date().timeIntervalSinceReferenceDate)
            return systemsCache.count > systemsCacheLimit
        }
        guard shouldTrim else { return }
        trimSystemsCache()
    }

    private func trimSystemsCache() {
        cacheLock.withLock {
            let overflow = systemsCache.count - systemsCacheLimit
            guard overflow > 0 else { return }
            let keysToRemove = systemsCache
                .sorted { $0.value.lastAccess < $1.value.lastAccess }
                .prefix(overflow)
                .map { $0.key }
            keysToRemove.forEach { systemsCache.removeValue(forKey: $0) }
        }
    }

    func findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(_ systems: [PVSystem], romFilename: String) -> [PVGame]? {
        let database = RomDatabase.sharedInstance
        var matches = [PVGame]()

        for system in systems {
            let gamePartialPath = (system.identifier as NSString).appendingPathComponent(romFilename)
            let games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), beginsWith: gamePartialPath)
            matches.append(contentsOf: games)
        }

        return matches.isEmpty ? nil : matches
    }

    func determineSystems(for item: ImportQueueItem) async throws -> [SystemIdentifier] {
        // For directory ROM sets (MAME or DOSBox), the system is resolved in performImport and
        // stored in item.systems before determineSystems is called.  Return it directly to bypass
        // the extension/MD5-based path (which doesn't understand directories).
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: item.url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            if !item.systems.isEmpty {
                DLOG("GameImporter: Using pre-determined systems for directory: \(item.url.lastPathComponent)")
                return item.systems
            }
            // Fallback: check for DOSBox folder via the shared importer helper to avoid duplicating the heuristic.
            if GameImporter.shared.isDOSBoxFolder(item) {
                DLOG("GameImporter: Detected DOSBox game folder (fallback): \(item.url.lastPathComponent)")
                return [.DOS]
            }
            DLOG("GameImporter: Directory \(item.url.lastPathComponent) is not a recognised game folder, skipping")
            return []
        }

        let filename = item.url.lastPathComponent
        let fileExtension = filename.components(separatedBy: ".").last?.lowercased() ?? ""
        /// Strip the file extension for database searches. The DB stores ROM filenames
        /// with original extensions (.bin, .cue, .iso) — container formats like .chd
        /// won't match. The `%..%` LIKE wrapping ensures extensionless names still
        /// match DB entries that have any extension.
        let searchFilename = (filename as NSString).deletingPathExtension
        let normalizedFilename = filename.lowercased()
        let parentDirectory = item.url.deletingLastPathComponent().lastPathComponent.lowercased()
        let cacheKey = SystemCacheKey(
            filename: normalizedFilename,
            fileExtension: fileExtension,
            parentDirectory: parentDirectory
        )

        @inline(__always)
        func cacheAndReturn(_ systems: [SystemIdentifier]) -> [SystemIdentifier] {
            cacheSystems(systems.isEmpty ? nil : systems, for: cacheKey)
            return systems
        }

        if let cached = cachedSystems(for: cacheKey) {
            switch cached {
            case .hit(let systems):
                DLOG("GameImporter: Using cached system match for \(filename)")
                return systems
            case .miss:
                DLOG("GameImporter: Cached miss for \(filename), returning no systems")
                return []
            }
        }

        DLOG("GameImporter: Determining systems for file:")
        DLOG("- Filename: \(filename)")
        DLOG("- Extracted extension: \(fileExtension)")

        /// Step 1: Check if file is already in a system directory (fastest check)
        if let system = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
            DLOG("Found system from path: \(system)")
            return cacheAndReturn([system])
        }

        /// Step 2: Extension-based filtering (cheapest - no DB queries)
        let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) ?? []
        var systemIdentifiers: [SystemIdentifier] = []
        for system in systems {
            let identifier = system.systemIdentifier
            if !systemIdentifiers.contains(identifier) {
                systemIdentifiers.append(identifier)
            }
        }
        DLOG("- Found \(systemIdentifiers.count) compatible systems by extension")

        let hasKnownExtension = !fileExtension.isEmpty && !systemIdentifiers.isEmpty
        let hasLimitedSystems = systemIdentifiers.count <= 3 /// Consider "limited" if 3 or fewer systems

        /// Step 2.5: If the extension uniquely identifies a single system (e.g. .jag, .j64, .gba),
        /// short-circuit before any MD5 hashing or database lookups. This avoids reading the
        /// entire ROM into memory just to confirm what the extension already told us.
        if systemIdentifiers.count == 1 {
            DLOG("Single system match by extension (fast path): \(systemIdentifiers.first!.rawValue)")
            return cacheAndReturn(systemIdentifiers)
        }

        /// Pre-compute MD5 asynchronously (off main thread) for use in lookup steps
        let itemMd5 = await item.md5Async()

        /// Step 3: If we have limited systems from extension, search PVLookup within those systems only
        if hasLimitedSystems && !systemIdentifiers.isEmpty {
            if let md5 = itemMd5 {
                /// Try MD5 lookup constrained to extension-matched systems (with filename fallback)
                if let systemID = try await lookup.systemIdentifier(
                    forRomMD5: md5,
                    or: searchFilename,
                    constrainedToSystems: systemIdentifiers,
                    allowFilenameSearch: true
                ) {
                    DLOG("Found system by MD5/filename within extension-matched systems: \(systemID)")
                    return cacheAndReturn([systemID])
                }
            } else if hasKnownExtension {
                /// If no MD5 but extension is known, try filename search within extension-matched systems
                if let results = try await lookup.searchDatabase(usingFilename: searchFilename, systemIDs: systemIdentifiers),
                   let firstResult = results.first {
                    DLOG("Found system by filename within extension-matched systems: \(firstResult.systemID)")
                    return cacheAndReturn([firstResult.systemID])
                }
            }
        }

        /// Step 5: If multiple systems from extension, try database + filename-based matching to narrow down
        if systemIdentifiers.count > 1 {
            /// Try database filename search constrained to extension-matched systems
            /// This catches multi-system formats like CHD where the game title in the DB
            /// disambiguates the system (e.g. "Duke Nukem - Time to Kill" → PSX)
            if let md5 = itemMd5 {
                if let systemID = try await lookup.systemIdentifier(
                    forRomMD5: md5,
                    or: searchFilename,
                    constrainedToSystems: systemIdentifiers,
                    allowFilenameSearch: true
                ) {
                    DLOG("Found system by MD5/filename within multi-system matches: \(systemID)")
                    return cacheAndReturn([systemID])
                }
            } else {
                /// No MD5 — try filename-only database search
                if let results = try await lookup.searchDatabase(usingFilename: searchFilename, systemIDs: systemIdentifiers),
                   let firstResult = results.first {
                    DLOG("Found system by filename within multi-system matches: \(firstResult.systemID)")
                    return cacheAndReturn([firstResult.systemID])
                }
            }

            /// Fallback: check if system name appears in the filename (e.g. "Game (PSX).chd")
            let filenameBasedSystems = findSystemsByNameInFilename(filename)
            if !filenameBasedSystems.isEmpty {
                DLOG("- Found \(filenameBasedSystems.count) systems by name in filename")

                let intersection = Set(systemIdentifiers).intersection(Set(filenameBasedSystems))
                if !intersection.isEmpty {
                    DLOG("- Found \(intersection.count) systems matching both extension and filename")
                    return cacheAndReturn(Array(intersection))
                }
            }

            /// Return the extension-matched systems (user will need to choose)
            return cacheAndReturn(systemIdentifiers)
        }

        /// Step 6: No extension match - if MD5 available, do wider MD5-only search (no filename)
        if systemIdentifiers.isEmpty, let md5 = itemMd5 {
            DLOG("No extension match, trying wider MD5-only search")
            if let systemID = try await lookup.systemIdentifier(
                forRomMD5: md5,
                or: nil, /// Don't search by filename for unknown extensions
                constrainedToSystems: nil,
                allowFilenameSearch: false
            ) {
                DLOG("Found system by MD5 (wide search): \(systemID)")
                return cacheAndReturn([systemID])
            }
        }

        /// Step 7: Fallback to filename-based system matching (if no extension match)
        if systemIdentifiers.isEmpty {
            let filenameBasedSystems = findSystemsByNameInFilename(filename)
            if !filenameBasedSystems.isEmpty {
                DLOG("- Found \(filenameBasedSystems.count) systems by name in filename (no extension match)")
                return cacheAndReturn(filenameBasedSystems)
            }
        }

        /// Step 8: Return whatever we found (may be empty)
        return cacheAndReturn(systemIdentifiers)
    }

    /// Find systems by looking for system names in the filename
    /// Checks for system names in various formats: "PSX", "(PSX)", "[PSX]"
    private func findSystemsByNameInFilename(_ filename: String) -> [SystemIdentifier] {
        /// Normalize the filename for easier matching
        let normalizedFilename = " \(filename.lowercased()) "

        /// Systems that match the filename
        var matchingSystems = [SystemIdentifier]()

        /// Check each system identifier
        for system in SystemIdentifier.allCases {
            /// Skip unknown system
            if system == .Unknown {
                continue
            }

            /// Get the system's short name
            let shortName = system.systemName
                .components(separatedBy: " - ")
                .last?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            /// Skip if no valid short name
            if shortName.isEmpty {
                continue
            }

            /// Check for various patterns in the filename
            let patterns = [
                " \(shortName) ",           // Surrounded by spaces
                "(\(shortName))",           // In parentheses
                "[\(shortName)]",           // In square brackets
                "{\(shortName)}"            // In curly braces
            ]

            for pattern in patterns {
                if normalizedFilename.contains(pattern.lowercased()) {
                    matchingSystems.append(system)
                    break
                }
            }

            /// Also check manufacturer name
            let manufacturer = system.manufacturer.lowercased()
            if !manufacturer.isEmpty && manufacturer != "unknown" && manufacturer != "various" {
                if normalizedFilename.contains(" \(manufacturer) ") ||
                   normalizedFilename.contains("(\(manufacturer))") ||
                   normalizedFilename.contains("[\(manufacturer)]") {
                    matchingSystems.append(system)
                }
            }
        }

        return matchingSystems
    }
}
