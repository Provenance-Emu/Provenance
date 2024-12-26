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
        let fileExtension = item.url.pathExtension.lowercased()
        return (PVEmulatorConfiguration.systemsFromCache(forFileExtension: fileExtension) ?? [])
            .compactMap { $0.systemIdentifier }
    }
}
