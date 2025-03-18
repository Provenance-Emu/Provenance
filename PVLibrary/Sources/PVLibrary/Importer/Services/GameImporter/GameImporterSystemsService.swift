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
        // First try MD5 lookup
        if let md5 = item.md5 {
            if let systemID = try await lookup.systemIdentifier(forRomMD5: md5, or: item.url.lastPathComponent) {
                return [systemID]
            }
        }

        // Fallback to extension-based lookup
        let filename = item.url.lastPathComponent
        let fileExtension = filename.components(separatedBy: ".").last?.lowercased() ?? ""

        DLOG("GameImporter: Determining systems for file:")
        DLOG("- Filename: \(filename)")
        DLOG("- Extracted extension: \(fileExtension)")

        let systems = PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) ?? []
        DLOG("- Found \(systems.count) compatible systems")

        let systemIdentifiers = systems.compactMap { $0.systemIdentifier }

        // If we have multiple systems or no systems, try to match by system name in filename
        if systemIdentifiers.count != 1 {
            let filenameBasedSystems = findSystemsByNameInFilename(filename)
            if !filenameBasedSystems.isEmpty {
                DLOG("- Found \(filenameBasedSystems.count) systems by name in filename")

                // If we have extension matches, find the intersection
                if !systemIdentifiers.isEmpty {
                    let intersection = Set(systemIdentifiers).intersection(Set(filenameBasedSystems))
                    if !intersection.isEmpty {
                        DLOG("- Found \(intersection.count) systems matching both extension and filename")
                        return Array(intersection)
                    }
                }

                return filenameBasedSystems
            }
        }

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
