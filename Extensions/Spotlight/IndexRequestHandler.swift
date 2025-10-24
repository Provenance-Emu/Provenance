//
//  IndexRequestHandler.swift
//  Spotlight
//
//  Created by Joseph Mattiello on 2/12/18.
//  Copyright © 2018,2025 Joseph Mattiello. All rights reserved.
//

import CoreSpotlight
import CoreServices
import PVLibrary
import PVSupport
import RealmSwift
import UniformTypeIdentifiers

public enum SpotlightError: Error {
    case appGroupsNotSupported
    case dontHandleDatatype
    case notFound
    case realmError(Error)
    case configurationError
}

public final class IndexRequestHandler: CSIndexExtensionRequestHandler {
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"
    
    /// Flag to use mock data instead of real data
    private let useMockData = false
    
    /// Mock data driver for testing
    private var mockDriver: MockSpotlightDataDriver?
    
    /// Safe database access methods using shared RomDatabase instance
    private func getGame(byMD5 md5: String) throws -> PVGame? {
        // Always use the shared RomDatabase instance to prevent corruption
        let database = RomDatabase.sharedInstance
        let realm = database.realm
        
        // Get the game and freeze it so it can be used across threads
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())?.freeze()
    }
    
    /// Get all games using shared database instance
    private func getAllGames() throws -> [PVGame] {
        // Use the shared RomDatabase instance to access Realm safely
        let database = RomDatabase.sharedInstance
        let realm = database.realm
        
        // Get all games and freeze them for thread safety
        return realm.objects(PVGame.self).map { $0.freeze() }
    }
    
    /// Get games matching specific identifiers
    private func getGames(withIdentifiers identifiers: [String]) throws -> [PVGame] {
        // Use the shared RomDatabase instance to access Realm safely
        let database = RomDatabase.sharedInstance
        let realm = database.realm
        
        // Get games with specific identifiers and freeze them
        let predicate = NSPredicate(format: "md5Hash IN %@", identifiers.map { $0.uppercased() })
        return realm.objects(PVGame.self).filter(predicate).map { $0.freeze() }
    }
    
    public override init() {
        super.init()
        
        if useMockData {
            // Initialize mock driver
            ILOG("Spotlight: Using mock data driver for testing")
            mockDriver = MockSpotlightDataDriver()
            Task {
                do {
                    try await mockDriver?.initialize()
                    ILOG("Spotlight: Mock driver initialized successfully")
                } catch {
                    ELOG("Spotlight: Error initializing mock driver: \(error)")
                }
            }
        } else {
            // Ensure RomDatabase is properly initialized
            // The shared instance will handle all configuration automatically
            do {
                // Verify the shared database is accessible
                let database = RomDatabase.sharedInstance
                let _ = database.realm // This will initialize if needed
                ILOG("Spotlight: Successfully connected to shared Realm database")
            } catch {
                ELOG("Spotlight: Failed to connect to shared Realm database: \(error)")
            }
            ILOG("Spotlight: Using shared RomDatabase instance")
        }
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing all searchable items")
        
        if useMockData, let mockDriver = mockDriver {
            do {
                // Get all games from mock driver
                let allGames = try mockDriver.getAllGames()
                
                if allGames.isEmpty {
                    WLOG("Spotlight: No mock games found to index")
                } else {
                    ILOG("Spotlight: Found \(allGames.count) mock games to index")
                    indexGames(allGames)
                }
            } catch {
                ELOG("Spotlight: Error getting mock games: \(error)")
            }
            
            acknowledgementHandler()
        } else {
            Task {
                do {
                    // Get all games using the shared RomDatabase instance
                    let allGames = try getAllGames()
                    
                    if allGames.isEmpty {
                        WLOG("Spotlight: No games found to index")
                    } else {
                        ILOG("Spotlight: Found \(allGames.count) games to index")
                        indexGames(allGames)
                    }
                } catch {
                    ELOG("Spotlight: Error getting games: \(error)")
                }
                
                // Always call the acknowledgement handler
                acknowledgementHandler()
            }
        }
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing items with identifiers: \(identifiers)")
        
        if useMockData, let mockDriver = mockDriver {
            do {
                // Get matching games from mock driver
                let matchingGames = try mockDriver.getGames(withIdentifiers: identifiers)
                
                if matchingGames.isEmpty {
                    WLOG("Spotlight: No matching mock games found for identifiers")
                } else {
                    ILOG("Spotlight: Found \(matchingGames.count) matching mock games to reindex")
                    indexGames(matchingGames)
                }
            } catch {
                ELOG("Spotlight: Error getting mock games with identifiers: \(error)")
            }
            
            acknowledgementHandler()
        } else if RealmConfiguration.supportsAppGroups {
            Task {
                do {
                    // Get specific games using the shared RomDatabase instance
                    let games = try getGames(withIdentifiers: identifiers)
                    
                    if games.isEmpty {
                        WLOG("Spotlight: No matching games found for identifiers")
                    } else {
                        ILOG("Spotlight: Found \(games.count) matching games to reindex")
                        indexGames(games)
                    }
                } catch {
                    ELOG("Spotlight: Error getting games with identifiers: \(error)")
                }
                
                // Always call the acknowledgement handler
                acknowledgementHandler()
            }
        } else {
            WLOG("Spotlight: App Groups not setup, cannot reindex")
            acknowledgementHandler()
        }
    }
    
    public override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data {
        /// This method is called when Spotlight needs data for a particular item
        ILOG("Spotlight: Request for data with itemIdentifier: \(itemIdentifier), typeIdentifier: \(typeIdentifier)")
        
        if !RealmConfiguration.supportsAppGroups {
            ELOG("Spotlight: App Groups not supported")
            throw SpotlightError.appGroupsNotSupported
        }
        
        if typeIdentifier == (kUTTypeImage as String) {
            do {
                let url = try fileURL(for: searchableIndex, itemIdentifier: itemIdentifier, typeIdentifier: typeIdentifier, inPlace: true)
                ILOG("Spotlight: Returning image data from URL: \(url.path)")
                return try Data(contentsOf: url)
            } catch {
                ELOG("Spotlight: Error getting image data: \(error)")
                throw error
            }
        } else {
            WLOG("Spotlight: Unsupported type identifier: \(typeIdentifier)")
            throw SpotlightError.dontHandleDatatype
        }
    }
    
    public override func fileURL(for _: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace _: Bool) throws -> URL {
        ILOG("Spotlight: Request for fileURL with itemIdentifier: \(itemIdentifier), typeIdentifier: \(typeIdentifier)")
        
        // We're assuming the typeIndentifier is the game one since that's all we've been using so far
        if typeIdentifier == UTType.rom.identifier {
            // Extract MD5 hash from the identifier (format: org.provenance-emu.game.MD5HASH)
            let md5 = itemIdentifier.components(separatedBy: ".").last ?? ""
            
            if useMockData, let mockDriver = mockDriver {
                // Use mock driver to get the game
                if let game = try mockDriver.getGame(byMD5: md5) {
                    // For mock games, we don't have real artwork URLs, so return a placeholder
                    ILOG("Spotlight: Using mock artwork for game with md5: \(md5)")
                    
                    // Create a temporary URL for testing
                    let tempDir = FileManager.default.temporaryDirectory
                    let artworkURL = tempDir.appendingPathComponent("\(game.title).png")
                    
                    // If the file doesn't exist, create a simple placeholder
                    if !FileManager.default.fileExists(atPath: artworkURL.path) {
                        // Create a simple placeholder image
                        let placeholderText = "Mock Artwork for \(game.title)"
                        let placeholderData = placeholderText.data(using: .utf8)
                        try? placeholderData?.write(to: artworkURL)
                    }
                    
                    return artworkURL
                } else {
                    WLOG("Spotlight: No mock game found with md5: \(md5)")
                    throw SpotlightError.notFound
                }
            } else {
                if !RealmConfiguration.supportsAppGroups {
                    ELOG("Spotlight: App Groups not supported")
                    throw SpotlightError.appGroupsNotSupported
                }
                
                // This is a synchronous method, so we need to use a fully synchronous approach
                // Get the Realm configuration directly
                // let config = RealmConfiguration.realmConfig
                
                // Create a new Realm instance directly
                let realm = try RomDatabase.sharedInstance.realm
                let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())
                
                if let game = game, let artworkURL = game.pathOfCachedImage {
                    ILOG("Spotlight: Found artwork for game with md5: \(md5)")
                    return artworkURL
                } else {
                    WLOG("Spotlight: No artwork found for game with md5: \(md5)")
                    throw SpotlightError.notFound
                }
            }
        } else {
            WLOG("Spotlight: Unsupported type identifier: \(typeIdentifier)")
            throw SpotlightError.dontHandleDatatype
        }
    }
    
    private func indexGames(_ games: [PVGame]) {
        ILOG("Spotlight: Indexing \(games.count) games")
        
        let items: [CSSearchableItem] = games.compactMap({ (game) -> CSSearchableItem? in
            if !game.md5Hash.isEmpty {
                let uniqueIdentifier = "org.provenance-emu.game.\(game.md5Hash)"
                let attributeSet = game.spotlightContentSet
                
                // Add system identifier if available
                if let system = game.system {
                    attributeSet.contentType = "\(system.manufacturer) \(system.name)"
                }
                
                // Add additional keywords for better searchability
                if var keywordsArray = attributeSet.keywords {
                    if let systemName = game.system?.name, !keywordsArray.contains(systemName) {
                        keywordsArray.append(systemName)
                    }
                    if let manufacturer = game.system?.manufacturer, !keywordsArray.contains(manufacturer) {
                        keywordsArray.append(manufacturer)
                    }
                    attributeSet.keywords = keywordsArray
                }
                
                // Make sure the items can appear in Siri suggestions
                attributeSet.domainIdentifier = self.domainIdentifier
                
                ILOG("Spotlight: Created searchable item for \(game.title)")
                return CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: self.domainIdentifier, attributeSet: attributeSet)
            } else {
                WLOG("Spotlight: Skipping game with empty md5Hash: \(game.title)")
                return nil
            }
        })
        
        if items.isEmpty {
            WLOG("Spotlight: No valid items to index")
            return
        }
        
        ILOG("Spotlight: Indexing \(items.count) searchable items")
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                ELOG("Spotlight: Indexing error: \(error)")
            } else {
                ILOG("Spotlight: Successfully indexed \(items.count) items")
            }
        }
    }
}
