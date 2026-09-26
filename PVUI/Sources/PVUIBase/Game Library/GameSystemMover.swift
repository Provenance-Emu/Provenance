//
//  GameSystemMover.swift
//  PVUIBase
//

import Foundation
import PVLibrary
import PVRealm
import RealmSwift

/// Moves a game to another system: its ROM files into that system's ROM directory,
/// then its database record. Shared by "Move to System" in the game picker, the
/// library view model and the multi-select batch move so they cannot drift apart.
public enum GameSystemMover {

    /// Moves `game`'s primary file and its `relatedFiles` (cue/bin, other discs) into
    /// `system`'s ROM directory, then repoints the record. Files move all-or-nothing, and
    /// if the database write fails they are moved back, so the files and the record never
    /// disagree about where the game lives.
    public static func move(_ game: PVGame, to system: PVSystem, in realm: Realm) throws {
        guard let sourceURL = PVEmulatorConfiguration.path(forGame: game) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let oldRomPath = game.romPath
        let oldSystemIdentifier = game.systemIdentifier
        let oldFileURL = game.file?.url
        let oldRelatedFiles = Array(game.relatedFiles.compactMap { $0.url })

        let destinationDirectory = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: system.identifier)
        let move = BatchFileMove(files: [sourceURL] + oldRelatedFiles, into: destinationDirectory)
        try move.perform()

        var movedGame: PVGame?
        do {
            try realm.write {
                guard !game.isInvalidated, let thawedGame = game.thaw() else { return }
                thawedGame.system = system
                thawedGame.systemIdentifier = system.identifier
                thawedGame.romPath = (system.identifier as NSString).appendingPathComponent(sourceURL.lastPathComponent)
                if let primary = move.pairs.first {
                    thawedGame.file = PVFile(withURL: primary.destination)
                }
                let movedRelated = move.pairs.filter { oldRelatedFiles.contains($0.source) }
                thawedGame.relatedFiles.removeAll()
                thawedGame.relatedFiles.append(objectsIn: movedRelated.map { PVFile(withURL: $0.destination) })
                thawedGame.isDownloaded = true
                movedGame = thawedGame
            }
        } catch {
            move.revert()
            throw error
        }

        guard let movedGame else {
            // The record vanished mid-move; put the files back where they were.
            move.revert()
            throw CocoaError(.fileNoSuchFile)
        }
        RomDatabase.removeGameFromCache(
            oldRomPath: oldRomPath,
            oldSystemIdentifier: oldSystemIdentifier,
            oldFileURL: oldFileURL,
            oldRelatedFiles: oldRelatedFiles
        )
        RomDatabase.addGameToCache(movedGame)
    }
}
