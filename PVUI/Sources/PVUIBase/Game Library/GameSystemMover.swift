//
//  GameSystemMover.swift
//  PVUIBase
//

import Foundation
import PVLibrary
import PVLogging
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
        let gameMD5 = game.md5Hash
        let systemIdentifier = system.identifier
        let oldRomPath = game.romPath
        let oldSystemIdentifier = game.systemIdentifier
        let oldFileURL = game.file?.url
        let oldRelatedFiles = Array(game.relatedFiles.compactMap { $0.url })

        let systemDirectory = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: system.identifier)
        // A multi-file set in a folder of its own moves into a folder of its own in the new system.
        let sourceSetFolder = MultiFileSetPlacement.setFolder(ofGameFileAt: sourceURL)
        let destinationDirectory = sourceSetFolder == nil ? systemDirectory : MultiFileSetPlacement.folder(
            forIndexAt: sourceURL, members: oldRelatedFiles, in: systemDirectory, identityMD5: game.md5Hash)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let move = BatchFileMove(files: [sourceURL] + oldRelatedFiles, into: destinationDirectory)
        try move.perform()

        var movedGame: PVGame?
        do {
            try realm.write {
                guard let (thawedGame, liveSystem) = resolveLiveObjects(gameMD5: gameMD5, systemIdentifier: systemIdentifier, in: realm) else {
                    return
                }
                thawedGame.system = liveSystem
                thawedGame.systemIdentifier = liveSystem.identifier
                thawedGame.romPath = RomDatabase.romPath(
                    for: destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent), systemIdentifier: liveSystem.identifier)
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
        if let sourceSetFolder,
           (try? FileManager.default.contentsOfDirectory(atPath: sourceSetFolder.path))?.isEmpty == true {
            try? FileManager.default.removeItem(at: sourceSetFolder)
        }
        RomDatabase.removeGameFromCache(
            oldRomPath: oldRomPath,
            oldSystemIdentifier: oldSystemIdentifier,
            oldFileURL: oldFileURL,
            oldRelatedFiles: oldRelatedFiles
        )
        RomDatabase.addGameToCache(movedGame)
    }

    /// Resolves the live game and system to edit inside `realm`'s write transaction.
    ///
    /// The tvOS media UI hands over frozen objects, and `thaw()` returns an object from whichever
    /// Realm instance matches the frozen one, or nil when its snapshot is stale. Neither is
    /// guaranteed to be the `realm` being written, so resolve both by primary key in it instead.
    static func resolveLiveObjects(gameMD5: String, systemIdentifier: String, in realm: Realm) -> (game: PVGame, system: PVSystem)? {
        guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameMD5), !liveGame.isInvalidated else {
            ELOG("GameSystemMover: could not resolve live game (md5: \(gameMD5))")
            return nil
        }
        guard let liveSystem = realm.object(ofType: PVSystem.self, forPrimaryKey: systemIdentifier), !liveSystem.isInvalidated else {
            ELOG("GameSystemMover: could not resolve live system '\(systemIdentifier)'")
            return nil
        }
        return (liveGame, liveSystem)
    }
}
