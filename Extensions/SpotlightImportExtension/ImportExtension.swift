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
import PVPrimitives
import PVSupport
import RealmSwift
import UniformTypeIdentifiers

// https://developer.apple.com/documentation/corespotlight/csimportextension

/// Errors that can occur during Spotlight import extension operations
enum ImportExtensionError: Error {
    case appGroupsNotSupported
    case fileNotFound
    case configurationError
    case realmError(Error)
}

/// Spotlight import extension for indexing Provenance game files
/// Note: CSImportExtension.update(_:forFileAt:) is synchronous, so we cannot use
/// Swift actors for Realm access here. Instead, we create thread-local Realm instances
/// with explicit configuration and freeze objects before use.
class ImportExtension: CSImportExtension {
    
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"
    
    /// Flag to track if Realm configuration has been set
    private static var realmConfigured = false
    
    override init() {
        super.init()
        
        // Set Realm configuration synchronously BEFORE any database access
        // This must happen before update(_:forFileAt:) is called
        Self.configureRealmIfNeeded()
        
        ILOG("SpotlightImport: Initializing Import Extension")
    }
    
    /// Configure Realm with the app group configuration
    /// This is idempotent and safe to call multiple times
    private static func configureRealmIfNeeded() {
        guard !realmConfigured else { return }
        
        RealmConfiguration.setDefaultRealmConfig()
        realmConfigured = true
        ILOG("SpotlightImport: Realm configuration set")
    }
    
    /// Create a properly configured Realm instance for the current thread
    /// - Returns: A configured Realm instance
    /// - Throws: RealmError if the database cannot be opened
    private func createRealm() throws -> Realm {
        // Ensure configuration is set (defensive check)
        Self.configureRealmIfNeeded()
        
        // Use explicit configuration for clarity and safety
        let config = RealmConfiguration.realmConfig
        return try Realm(configuration: config)
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
            // Create Realm with proper configuration
            let realm = try createRealm()
            
            let predicate = NSPredicate(format: "md5Hash == %@", md5Hash)
            
            // Freeze the object for thread safety before passing to other methods
            if let game = realm.objects(PVGame.self).filter(predicate).first?.freeze() {
                ILOG("SpotlightImport: Found game: \(game.title) for MD5: \(md5Hash)")
                
                // Transfer game metadata to search attributes (game is frozen, safe to use)
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
                // Create Realm with proper configuration (no force unwrap)
                let realm = try createRealm()
                
                let predicate = NSPredicate(format: "md5Hash == %@", potentialMD5)
                
                // Freeze the object for thread safety
                if let game = realm.objects(PVGame.self).filter(predicate).first?.freeze() {
                    ILOG("SpotlightImport: Found game for save state: \(game.title)")
                    
                    // Set save state specific attributes
                    attributes.displayName = "Save State: \(game.title)"
                    attributes.contentDescription = "Save state for \(game.title) on \(game.system?.name ?? "Unknown System")"
                    
                    // Add game metadata (game is frozen, safe to use)
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
    /// - Parameters:
    ///   - attributes: The searchable item attributes to update
    ///   - game: A frozen PVGame object (must be frozen for thread safety)
    private func updateAttributesFromGame(_ attributes: CSSearchableItemAttributeSet, game: PVGame) {
        // Defensive check: ensure the game object is still valid
        guard !game.isInvalidated else {
            WLOG("SpotlightImport: Game object is invalidated, skipping attribute update")
            return
        }
        
        // Basic metadata
        attributes.displayName = game.title
        attributes.contentDescription = game.gameDescription ?? "Game for \(game.system?.name ?? "Unknown System")"
        
        // Content type
        if let system = game.system, !system.isInvalidated {
            attributes.contentType = "\(system.manufacturer) \(system.name)"
        } else {
            attributes.contentType = "org.provenance-emu.game"
        }
        
        // Set creation date if available
        if let publishDate = game.publishDate {
            // Convert string publish date to NSDate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy"
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
        
        // Add system name (with safety check)
        if let system = game.system, !system.isInvalidated {
            let systemName = system.name
            keywords.append(systemName)
            // Add system variations
            if systemName.contains(" ") {
                keywords.append(contentsOf: systemName.components(separatedBy: " "))
            }
            
            // Add manufacturer
            let manufacturer = system.manufacturer
            if !manufacturer.isEmpty {
                keywords.append(manufacturer)
            }
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
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: imagePath),
               let scaledImage = image.scaledImage(withMaxResolution: 300) {
                attributes.thumbnailData = scaledImage.jpegData(compressionQuality: 0.9)
            }
            #endif
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
