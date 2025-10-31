//
//  GameImporterSystemsService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/7/24.
//

import Foundation
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

    init(lookup: PVLookup = .shared) {
        self.lookup = lookup
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
        let filename = item.url.lastPathComponent
        let fileExtension = filename.components(separatedBy: ".").last?.lowercased() ?? ""

        DLOG("GameImporter: Determining systems for file:")
        DLOG("- Filename: \(filename)")
        DLOG("- Extracted extension: \(fileExtension)")

        /// Step 1: Check if file is already in a system directory (fastest check)
        if let system = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
            DLOG("Found system from path: \(system)")
            return [system]
        }

        /// Step 2: Extension-based filtering (cheapest - no DB queries)
        let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) ?? []
        let systemIdentifiers = systems.compactMap { $0.systemIdentifier }
        DLOG("- Found \(systemIdentifiers.count) compatible systems by extension")

        let hasKnownExtension = !fileExtension.isEmpty && !systemIdentifiers.isEmpty
        let hasLimitedSystems = systemIdentifiers.count <= 3 /// Consider "limited" if 3 or fewer systems

        /// Step 3: If we have limited systems from extension, search PVLookup within those systems only
        if hasLimitedSystems && !systemIdentifiers.isEmpty {
            if let md5 = item.md5 {
                /// Try MD5 lookup constrained to extension-matched systems (with filename fallback)
                if let systemID = try await lookup.systemIdentifier(
                    forRomMD5: md5,
                    or: filename,
                    constrainedToSystems: systemIdentifiers,
                    allowFilenameSearch: true
                ) {
                    DLOG("Found system by MD5/filename within extension-matched systems: \(systemID)")
                    return [systemID]
                }
            } else if hasKnownExtension {
                /// If no MD5 but extension is known, try filename search within extension-matched systems
                if let results = try await lookup.searchDatabase(usingFilename: filename, systemIDs: systemIdentifiers),
                   let firstResult = results.first {
                    DLOG("Found system by filename within extension-matched systems: \(firstResult.systemID)")
                    return [firstResult.systemID]
                }
            }
        }

        /// Step 4: If we have extension matches but no constrained lookup match, return them
        if systemIdentifiers.count == 1 {
            DLOG("Single system match by extension: \(systemIdentifiers.first!.rawValue)")
            return systemIdentifiers
        }

        /// Step 5: If multiple systems from extension, try filename-based matching to narrow down
        if systemIdentifiers.count > 1 {
            let filenameBasedSystems = findSystemsByNameInFilename(filename)
            if !filenameBasedSystems.isEmpty {
                DLOG("- Found \(filenameBasedSystems.count) systems by name in filename")

                /// Find intersection of extension and filename matches
                let intersection = Set(systemIdentifiers).intersection(Set(filenameBasedSystems))
                if !intersection.isEmpty {
                    DLOG("- Found \(intersection.count) systems matching both extension and filename")
                    return Array(intersection)
                }
            }

            /// If we still have multiple systems but MD5 available, try constrained MD5 search
            if let md5 = item.md5 {
                if let systemID = try await lookup.systemIdentifier(
                    forRomMD5: md5,
                    or: nil, /// Don't use filename for multi-system matches
                    constrainedToSystems: systemIdentifiers,
                    allowFilenameSearch: false
                ) {
                    DLOG("Found system by MD5 within extension-matched systems: \(systemID)")
                    return [systemID]
                }
            }

            /// Return the extension-matched systems (user will need to choose)
            return systemIdentifiers
        }

        /// Step 6: No extension match - if MD5 available, do wider MD5-only search (no filename)
        if systemIdentifiers.isEmpty, let md5 = item.md5 {
            DLOG("No extension match, trying wider MD5-only search")
            if let systemID = try await lookup.systemIdentifier(
                forRomMD5: md5,
                or: nil, /// Don't search by filename for unknown extensions
                constrainedToSystems: nil,
                allowFilenameSearch: false
            ) {
                DLOG("Found system by MD5 (wide search): \(systemID)")
                return [systemID]
            }
        }

        /// Step 7: Fallback to filename-based system matching (if no extension match)
        if systemIdentifiers.isEmpty {
            let filenameBasedSystems = findSystemsByNameInFilename(filename)
            if !filenameBasedSystems.isEmpty {
                DLOG("- Found \(filenameBasedSystems.count) systems by name in filename (no extension match)")
                return filenameBasedSystems
            }
        }

        /// Step 8: Return whatever we found (may be empty)
        return systemIdentifiers
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
