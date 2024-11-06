//
//  GameImporter+Roms.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVCoreLoader
import AsyncAlgorithms
import PVPlists
import PVLookup
import Systems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm
import Perception
import SwiftUI

public extension GameImporter {
    
//    /// Retrieves ROM information for files at given paths
//    func getRomInfoForFiles(atPaths paths: [URL], userChosenSystem chosenSystem: System? = nil) async {
//        //TODO: split this off at the importer queue entry point so we can remove here
//        // If directory, map out sub directories if folder
//        let paths: [URL] = paths.compactMap { (url) -> [URL]? in
//            if url.hasDirectoryPath {
//                return try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
//            } else {
//                return [url]
//            }
//        }.joined().map { $0 }
//        
//        let sortedPaths = PVEmulatorConfiguration.sortImportURLs(urls: paths)
//        await sortedPaths.asyncForEach { path in
//            do {
//                try await self._handlePath(path: path, userChosenSystem: chosenSystem)
//            } catch {
//                //TODO: what do i do here?  I probably could just let this throw...
//                ELOG("\(error)")
//            }
//        } // for each
//    }
    
//    internal func importGame(path: URL, system: PVSystem) throws {
//        DLOG("Attempting to import game: \(path.lastPathComponent) for system: \(system.name)")
//        let filename = path.lastPathComponent
//        let partialPath = (system.identifier as NSString).appendingPathComponent(filename)
//        let similarName = RomDatabase.altName(path, systemIdentifier: system.identifier)
//        
//        DLOG("Checking game cache for partialPath: \(partialPath) or similarName: \(similarName)")
//        let gamesCache = RomDatabase.gamesCache
//        
//        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
//           system.identifier == existingGame.systemIdentifier {
//            DLOG("Found existing game in cache, saving relative path")
//            saveRelativePath(existingGame, partialPath: partialPath, file: path)
//        } else {
//            DLOG("No existing game found, starting import to database")
//            Task.detached(priority: .utility) {
//                try await self.importToDatabaseROM(atPath: path, system: system, relatedFiles: nil)
//            }
//        }
//    }
//    
//    /// Imports a ROM to the database
//    internal func importToDatabaseROM(atPath path: URL, system: PVSystem, relatedFiles: [URL]?) async throws {
//        DLOG("Starting database ROM import for: \(path.lastPathComponent)")
//        let filename = path.lastPathComponent
//        let filenameSansExtension = path.deletingPathExtension().lastPathComponent
//        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
//        let destinationDir = (system.identifier as NSString)
//        let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)
//        
//        DLOG("Creating game object with title: \(title), partialPath: \(partialPath)")
//        let file = PVFile(withURL: path)
//        let game = PVGame(withFile: file, system: system)
//        game.romPath = partialPath
//        game.title = title
//        game.requiresSync = true
//        var relatedPVFiles = [PVFile]()
//        let files = RomDatabase.getFileSystemROMCache(for: system).keys
//        let name = RomDatabase.altName(path, systemIdentifier: system.identifier)
//        
//        DLOG("Searching for related files with name: \(name)")
//        
//        await files.asyncForEach { url in
//            let relativeName = RomDatabase.altName(url, systemIdentifier: system.identifier)
//            DLOG("Checking file \(url.lastPathComponent) with relative name: \(relativeName)")
//            if relativeName == name {
//                DLOG("Found matching related file: \(url.lastPathComponent)")
//                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
//            }
//        }
//        
//        if let relatedFiles = relatedFiles {
//            DLOG("Processing \(relatedFiles.count) additional related files")
//            for url in relatedFiles {
//                DLOG("Adding related file: \(url.lastPathComponent)")
//                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
//            }
//        }
//        
//        guard let md5 = calculateMD5(forGame: game)?.uppercased() else {
//            ELOG("Couldn't calculate MD5 for game \(partialPath)")
//            throw GameImporterError.couldNotCalculateMD5
//        }
//        DLOG("Calculated MD5: \(md5)")
//        
//        // Register import with coordinator
//        guard await importCoordinator.checkAndRegisterImport(md5: md5) else {
//            DLOG("Import already in progress for MD5: \(md5)")
//            throw GameImporterError.romAlreadyExistsInDatabase
//        }
//        DLOG("Registered import with coordinator for MD5: \(md5)")
//        
//        defer {
//            Task {
//                await importCoordinator.completeImport(md5: md5)
//                DLOG("Completed import coordination for MD5: \(md5)")
//            }
//        }
//        
//        game.relatedFiles.append(objectsIn: relatedPVFiles)
//        game.md5Hash = md5
//        try await finishUpdateOrImport(ofGame: game, path: path)
//    }
}
