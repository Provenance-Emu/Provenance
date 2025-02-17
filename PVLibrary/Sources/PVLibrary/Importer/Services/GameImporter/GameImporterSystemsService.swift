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
        // if syncing from icloud, we have the system, so try to get the system this way
        if let system = SystemIdentifier(rawValue: item.url.deletingLastPathComponent().lastPathComponent) {
            DLOG("found system: \(system)")
            return [system]
        }
        // next try MD5 lookup
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

        return systems.compactMap { $0.systemIdentifier }
    }
}
