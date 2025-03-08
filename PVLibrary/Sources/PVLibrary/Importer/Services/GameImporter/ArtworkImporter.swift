//
//  ArtworkImporter.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import PVPrimitives

protocol ArtworkImporting {
    // TODO: Make me more generic
//    associatedtype MyGameImporterSystemsService: GameImporterSystemsServicing
    typealias MyGameImporterSystemsService = GameImporterSystemsServicing

    func setSystemsService(_ systemsService: MyGameImporterSystemsService)
    func importArtworkItem(_ queueItem: ImportQueueItem) async -> MyGameImporterSystemsService.GameType?
}

class ArtworkImporter : ArtworkImporting {
            
    private var gameImporterSystemsService: (any GameImporterSystemsServicing)?
    
    init() {
        
    }
    
    func setSystemsService(_ systemsService: MyGameImporterSystemsService) {
        gameImporterSystemsService = systemsService
    }
    
    func importArtworkItem(_ queueItem: ImportQueueItem) async -> MyGameImporterSystemsService.GameType? {
        guard queueItem.fileType == .artwork else {
            return nil
        }
        
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: queueItem.url.path, isDirectory: &isDirectory)
        if !fileExists || isDirectory.boolValue {
            WLOG("File doesn't exist or is directory at \(queueItem.url)")
            return nil
        }
        
        var success = false
        
        defer {
            if success {
                do {
                    //clean up...
                    try FileManager.default.removeItem(at: queueItem.url)
                } catch {
                    ELOG("Failed to delete image at path \(queueItem.url) \n \(error.localizedDescription)")
                }
            }
        }
        
        //I think what this does is rely on a file being something like game.sfc.jpg or something?
        let gameFilename: String = queueItem.url.deletingPathExtension().lastPathComponent
        let gameExtension = queueItem.url.deletingPathExtension().pathExtension
        let database = RomDatabase.sharedInstance
        
        if gameExtension.isEmpty {
            ILOG("Trying to import artwork that didn't contain the extension of the system")
            let games = database.all(PVGame.self, filter: NSPredicate(format: "romPath CONTAINS[c] %@", argumentArray: [gameFilename]))
            
            if games.count == 1, let game = games.first {
                ILOG("File for image didn't have extension for system but we found a single match for image \(queueItem.url.lastPathComponent) to game \(game.title) on system \(game.systemIdentifier)")
                guard let hash = scaleAndMoveImageToCache(imageFullPath: queueItem.url) else {
                    return nil
                }
                
                do {
                    try database.writeTransaction {
                        game.customArtworkURL = hash
                    }
                    success = true
                    ILOG("Set custom artwork of game \(game.title) from file \(queueItem.url.lastPathComponent)")
                } catch {
                    ELOG("Couldn't update game \(game.title) with new artwork URL \(hash)")
                }
                
                return game
            } else {
                VLOG("Database search returned \(games.count) results")
                //TODO: consider either using it for all or asking the user what to do - for now this is an error
            }
        }
        
        guard let systems: [PVSystem] = PVEmulatorConfiguration.systemsFromCache(forFileExtension: gameExtension), !systems.isEmpty else {
            ELOG("No system for extension \(gameExtension)")
            return nil
        }
        
        let cdBasedSystems = PVEmulatorConfiguration.cdBasedSystems
        let couldBelongToCDSystem = !Set(cdBasedSystems).isDisjoint(with: Set(systems))
        
        if (couldBelongToCDSystem && PVEmulatorConfiguration.supportedCDFileExtensions.contains(gameExtension.lowercased())) || systems.count > 1 {
            guard let existingGames = gameImporterSystemsService?.findAnyCurrentGameThatCouldBelongToAnyOfTheseSystems(systems, romFilename: gameFilename) else {
                ELOG("System for extension \(gameExtension) is a CD system and {\(gameExtension)} not the right matching file type of cue or m3u")
                return nil
            }
            if existingGames.count == 1, let onlyMatch = existingGames.first {
                ILOG("We found a hit for artwork that could have been belonging to multiple games and only found one file that matched by systemid/filename. The winner is \(onlyMatch.title) for \(onlyMatch.systemIdentifier)")
                
                guard let hash = scaleAndMoveImageToCache(imageFullPath: queueItem.url) else {
                    ELOG("Couldn't move image, fail to set custom artwork")
                    return nil
                }
                
                do {
                    try database.writeTransaction {
                        onlyMatch.customArtworkURL = hash
                    }
                    success = true
                } catch {
                    ELOG("Couldn't update game \(onlyMatch.title) with new artwork URL")
                }
                return onlyMatch as? PVGame
            } else {
                ELOG("We got to the unlikely scenario where an extension is possibly a CD binary file, or belongs to a system, and had multiple games that matched the filename under more than one core.")
                return nil
            }
        }
        
        guard let system = systems.first else {
            ELOG("systems empty")
            return nil
        }
        
        var gamePartialPath: String = URL(fileURLWithPath: system.identifier, isDirectory: true).appendingPathComponent(gameFilename).deletingPathExtension().path
        if gamePartialPath.first == "/" {
            gamePartialPath.removeFirst()
        }
        
        if gamePartialPath.isEmpty {
            ELOG("Game path was empty")
            return nil
        }
        
        var games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), value: gamePartialPath)
        if games.isEmpty {
            games = database.all(PVGame.self, where: #keyPath(PVGame.romPath), beginsWith: gamePartialPath)
        }
        
        guard !games.isEmpty else {
            ELOG("Couldn't find game for path \(gamePartialPath)")
            return nil
        }
        
        if games.count > 1 {
            WLOG("There were multiple matches for \(gamePartialPath)! #\(games.count). Going with first for now until we make better code to prompt user.")
        }
        
        let game = games.first!
        
        guard let hash = scaleAndMoveImageToCache(imageFullPath: queueItem.url) else {
            ELOG("scaleAndMoveImageToCache failed")
            return nil
        }
        
        do {
            try database.writeTransaction {
                game.customArtworkURL = hash
            }
            success = true
        } catch {
            ELOG("Couldn't update game with new artwork URL")
        }
        
        return game
    }
    
    /// Scales and moves an image to the cache
    private func scaleAndMoveImageToCache(imageFullPath: URL) -> String? {
        let coverArtFullData: Data
        do {
            coverArtFullData = try Data(contentsOf: imageFullPath, options: [])
        } catch {
            ELOG("Couldn't read data from image file \(imageFullPath.path)\n\(error.localizedDescription)")
            return nil
        }
        
#if canImport(UIKit)
        guard let coverArtFullImage = UIImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        guard let coverArtScaledImage = coverArtFullImage.scaledImage(withMaxResolution: Int(PVThumbnailMaxResolution)) else {
            ELOG("Failed to create scale image")
            return nil
        }
#else
        guard let coverArtFullImage = NSImage(data: coverArtFullData) else {
            ELOG("Failed to create Image from data")
            return nil
        }
        let coverArtScaledImage = coverArtFullImage
#endif
        
#if canImport(UIKit)
        guard let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.95) else {
            ELOG("Failed to create data representation of scaled image")
            return nil
        }
#else
        let coverArtScaledData = coverArtScaledImage.jpegData(compressionQuality: 0.95)
#endif
        
        let hash: String = (coverArtScaledData as NSData).md5
        
        do {
            let destinationURL = try PVMediaCache.writeData(toDisk: coverArtScaledData, withKey: hash)
            VLOG("Scaled and moved image from \(imageFullPath.path) to \(destinationURL.path)")
        } catch {
            ELOG("Failed to save artwork to cache: \(error.localizedDescription)")
            return nil
        }
        
        return hash
    }
}
