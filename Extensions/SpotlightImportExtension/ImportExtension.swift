//
//  ImportExtension.swift
//  SpotlightImportExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift
import UniformTypeIdentifiers

// https://developer.apple.com/documentation/corespotlight/csimportextension

enum ImportExtensionError: Error {
    case appGroupsNotSupported
    case fileNotFound
    case configurationError
    case realmError(Error)
}

class ImportExtension: CSImportExtension {
    
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"
    
    /// Actor to isolate Realm database access safely
    private actor RealmActor {
        
        /// Get a game by its MD5 hash using shared database instance
        func getGame(byMD5 md5: String) throws -> PVGame? {
            // Always use the shared RomDatabase instance to prevent corruption
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            // Get the game and freeze it so it can be used across threads
            let predicate = NSPredicate(format: "md5Hash == %@", md5)
            return realm.objects(PVGame.self).filter(predicate).first?.freeze()
        }
        
        /// Get all games using shared database instance
        func getAllGames() throws -> [PVGame] {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            // Get all games and freeze them for thread safety
            return realm.objects(PVGame.self).map { $0.freeze() }
        }
    }
    
    /// Realm actor instance
    private let realmActor = RealmActor()
    
    override init() {
        super.init()
        
        ILOG("SpotlightImport: Initializing Import Extension")
        
        // Ensure RomDatabase is properly initialized
        // The shared instance will handle all configuration automatically
        Task {
            do {
                // Verify the shared database is accessible
                let database = RomDatabase.sharedInstance
                let _ = database.realm // This will initialize if needed
                ILOG("SpotlightImport: Successfully connected to shared Realm database")
            } catch {
                ELOG("SpotlightImport: Failed to connect to shared Realm database: \(error)")
            }
        }
    }
    
    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt fileURL: URL) throws {
        ILOG("SpotlightImport: Indexing file at \(fileURL.path)")
        
        // Check if app groups are supported
        if !RealmConfiguration.supportsAppGroups {
            ELOG("SpotlightImport: App Groups not supported, cannot index file")
            throw NSError(domain: "ImportExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Groups not supported"])
        }
        
        // Check file existence
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            ELOG("SpotlightImport: File doesn't exist at path: \(fileURL.path)")
            throw NSError(domain: "ImportExtension", code: 2, userInfo: [NSLocalizedDescriptionKey: "File doesn't exist"])
        }
        
        // Get file extension to determine type
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Determine if this is a ROM file, save state, or other file type
        if isROMFile(fileExtension) {
            try indexROMFile(attributes, fileURL: fileURL)
        } else if fileExtension == "pvsav" {
            try indexSaveState(attributes, fileURL: fileURL)
        } else {
            // For other file types, provide basic indexing
            ILOG("SpotlightImport: Indexing unknown file type with extension: \(fileExtension)")
            attributes.displayName = fileURL.deletingPathExtension().lastPathComponent
            attributes.contentType = fileExtension
            attributes.keywords = ["provenance", "emulator", fileExtension]
        }
    }
    
    /// Index a ROM file by looking up its MD5 hash in the database
    private func indexROMFile(_ attributes: CSSearchableItemAttributeSet, fileURL: URL) throws {
        ILOG("SpotlightImport: Indexing ROM file: \(fileURL.lastPathComponent)")
        
        // Get MD5 hash of the file
        guard let md5Hash = FileManager.default.md5ForFile(at: fileURL, fromOffset: 0) else {
            WLOG("SpotlightImport: Could not generate MD5 hash for file")
            attributes.displayName = fileURL.deletingPathExtension().lastPathComponent
            return
        }
        
        ILOG("SpotlightImport: Generated MD5 hash: \(md5Hash)")
        
        do {
            // This is a synchronous method, so we need to use a fully synchronous approach
            // Get the configuration directly
//            let config = RealmConfiguration.realmConfig
            
            // Create a new Realm instance directly
//            let realm = try Realm(configuration: config)
            let realm = try RomDatabase.sharedInstance.realm

            let predicate = NSPredicate(format: "md5Hash == %@", md5Hash)
            let game = realm.objects(PVGame.self).filter(predicate).first
            
            if let game = game {
                ILOG("SpotlightImport: Found game: \(game.title) for MD5: \(md5Hash)")
                
                // Transfer game metadata to search attributes
                updateAttributesFromGame(attributes, game: game)
                
                // Add unique identifier for opening the game
                attributes.relatedUniqueIdentifier = "org.provenance-emu.game.\(md5Hash)"
            } else {
                WLOG("SpotlightImport: No game found with MD5 hash: \(md5Hash)")
                
                // Set basic attributes if game not found
                attributes.displayName = fileURL.deletingPathExtension().lastPathComponent
                attributes.contentType = UTType.rom.identifier
                attributes.keywords = ["rom", "game", "provenance", "emulator"]
            }
        } catch {
            ELOG("SpotlightImport: Error looking up game: \(error)")
            
            // Set basic attributes if there was an error
            attributes.displayName = fileURL.deletingPathExtension().lastPathComponent
            attributes.contentType = UTType.rom.identifier
            attributes.keywords = ["rom", "game", "provenance", "emulator"]
        }
    }
    
    /// Index a save state file
    private func indexSaveState(_ attributes: CSSearchableItemAttributeSet, fileURL: URL) throws {
        ILOG("SpotlightImport: Indexing save state file: \(fileURL.lastPathComponent)")
        
        // Get filename components
        let filename = fileURL.deletingPathExtension().lastPathComponent
        
        // Save state filename format is typically: GameTitle-MD5Hash-SlotNumber.pvsav
        let components = filename.components(separatedBy: "-")
        
        if components.count >= 2 {
            let potentialMD5 = components[components.count - 2]
            
            do {
                // This is a synchronous method, so we need to use a fully synchronous approach
                // Get the configuration directly
//                let config = RealmConfiguration.realmConfig
                
                // Create a new Realm instance directly
//                let realm = try Realm(configuration: config)
                let realm = RomDatabase.sharedInstance.realm

                let predicate = NSPredicate(format: "md5Hash == %@", potentialMD5)
                let game = realm.objects(PVGame.self).filter(predicate).first
                
                if let game = game {
                    ILOG("SpotlightImport: Found game for save state: \(game.title)")
                    
                    // Set save state specific attributes
                    attributes.displayName = "Save State: \(game.title)"
                    attributes.contentDescription = "Save state for \(game.title) on \(game.system?.name ?? "Unknown System")"
                    
                    // Add game metadata
                    updateAttributesFromGame(attributes, game: game)
                    
                    // Add save state specific keywords
                    if var keywords = attributes.keywords {
                        keywords.append(contentsOf: ["save state", "saved game"])
                        attributes.keywords = keywords
                    }
                    
                    // Set related unique identifier
                    attributes.relatedUniqueIdentifier = "org.provenance-emu.savestate.\(fileURL.lastPathComponent)"
                    
                    return
                }
            } catch {
                ELOG("SpotlightImport: Error looking up game for save state: \(error)")
                // Continue to fallback case
            }
        }
        
        // Fallback for save states we couldn't associate with a game
        attributes.displayName = "Save State: \(fileURL.deletingPathExtension().lastPathComponent)"
        attributes.contentType = "org.provenance-emu.savestate"
        attributes.keywords = ["save state", "provenance", "emulator", "saved game"]
    }
    
    /// Update search attributes from a game object
    private func updateAttributesFromGame(_ attributes: CSSearchableItemAttributeSet, game: PVGame) {
        // Basic metadata
        attributes.displayName = game.title
        attributes.contentDescription = game.gameDescription ?? "Game for \(game.system?.name ?? "Unknown System")"
        
        // Content type
        if let system = game.system {
            attributes.contentType = "\(system.manufacturer) \(system.name)"
        } else {
            attributes.contentType = "org.provenance-emu.game"
        }
        
        // Set creation date if available
        if let publishDate = game.publishDate {
            // Convert string publish date to NSDate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy" // Assuming the publish date is just a year
            if let date = dateFormatter.date(from: publishDate) {
                attributes.contentCreationDate = date
            }
        }
        
        // Add developer as author
        if let developer = game.developer, !developer.isEmpty {
            attributes.authorNames = [developer]
        }
        
        // Keywords for better searchability
        var keywords = ["rom", "game", "emulator", "provenance"]
        
        // Add system name
        if let systemName = game.system?.name {
            keywords.append(systemName)
            // Add system variations
            if systemName.contains(" ") {
                keywords.append(contentsOf: systemName.components(separatedBy: " "))
            }
        }
        
        // Add manufacturer
        if let manufacturer = game.system?.manufacturer {
            keywords.append(manufacturer)
        }
        
        // Add genres
        if let genres = game.genres, !genres.isEmpty {
            keywords.append(contentsOf: genres.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        
        // Add title keywords
        keywords.append(game.title)
        if game.title.contains(" ") {
            let titleWords = game.title.components(separatedBy: " ")
            keywords.append(contentsOf: titleWords.filter { $0.count > 2 })
        }
        
        // Convert to NSArray for CoreSpotlight
        attributes.keywords = keywords
        
        // Add thumbnail image if available
        if let artworkURL = game.pathOfCachedImage {
            attributes.thumbnailURL = artworkURL
            
            let imagePath = artworkURL.path
            // Try to load the image data
            if let image = UIImage(contentsOfFile: imagePath),
               let scaledImage = image.scaledImage(withMaxResolution: 300) {
                attributes.thumbnailData = scaledImage.jpegData(compressionQuality: 0.9)
            }
        }
        
        // Rating for favorites
        attributes.rating = NSNumber(value: game.isFavorite ? 5 : 0)
    }
    
    /// Determine if a file extension represents a ROM file
    private func isROMFile(_ fileExtension: String) -> Bool {
        // Common ROM file extensions
        let romExtensions = [
            "nes", "smc", "sfc", "gb", "gbc", "gba", "md", "smd", "gen",
            "32x", "cue", "iso", "z64", "n64", "v64", "nds", "3ds",
            "sms", "gg", "ws", "wsc", "pce", "ngp", "ngc", "a26", "a78",
            "j64", "jag", "lnx", "vec", "fds", "rom", "bin"
        ]
        
        return romExtensions.contains(fileExtension.lowercased())
    }
}
