//
//  TopShelfDataDriver.swift
//  TopShelfv2
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import TVServices
import PVLibrary
import os.log
import RealmSwift

// We only need the schema version from PVLibrary
private let topShelfSchemaVersion = schemaVersion

/// Protocol defining the interface for TopShelf data drivers
protocol TopShelfDataDriver {
    /// Initialize the driver
    func initialize() async throws
    
    /// Get recently played games
    func getRecentlyPlayedGames(limit: Int) async -> [PVGame]
    
    /// Get favorite games
    func getFavoriteGames(limit: Int) async -> [PVGame]
    
    /// Get recently added games
    func getRecentlyAddedGames(limit: Int) async -> [PVGame]
    
    /// Get a game by ID
    func getGame(byID id: String) async -> PVGame?
    
    /// Get any error messages from the driver
    var errorMessages: [String] { get }
}

/// Mock implementation of TopShelfDataDriver for development and testing
class MockTopShelfDataDriver: TopShelfDataDriver {
    /// Collection of error messages for debugging
    private(set) var errorMessages: [String] = []
    /// Collection of mock games
    private var games: [PVGame] = []
    
    /// Collection of mock recent games
    private var recentGames: [PVRecentGame] = []
    
    /// Initialize the driver with mock data
    func initialize() async throws {
        // Create mock games
        createMockData()
    }
    
    /// Get recently played games
    func getRecentlyPlayedGames(limit: Int) -> [PVGame] {
        // Sort by last played date and return the most recent ones
        return Array(recentGames.prefix(limit).compactMap { recentGame in
            return games.first { $0.md5Hash == recentGame.game.md5Hash }
        })
    }
    
    /// Get favorite games
    func getFavoriteGames(limit: Int) -> [PVGame] {
        // Filter for favorites and sort by title
        return Array(games.filter { $0.isFavorite }.sorted { $0.title < $1.title }.prefix(limit))
    }
    
    /// Get recently added games
    func getRecentlyAddedGames(limit: Int) -> [PVGame] {
        // Sort by import date and return the most recent ones
        return Array(games.sorted { $0.importDate > $1.importDate }.prefix(limit))
    }
    
    /// Get a game by ID
    func getGame(byID id: String) -> PVGame? {
        return games.first { $0.md5Hash == id }
    }
    
    /// Create mock data for testing
    private func createMockData() {
        // Create some mock systems
        let nesSystem = PVSystem()
        nesSystem.identifier = "NES"
        nesSystem.name = "Nintendo Entertainment System"
        
        let snesSystem = PVSystem()
        snesSystem.identifier = "SNES"
        snesSystem.name = "Super Nintendo"
        
        let genesisSystem = PVSystem()
        genesisSystem.identifier = "Genesis"
        genesisSystem.name = "Sega Genesis"
        
        let gbaSystem = PVSystem()
        gbaSystem.identifier = "GBA"
        gbaSystem.name = "Game Boy Advance"
        
        let psx = PVSystem()
        psx.identifier = "PSX"
        psx.name = "PlayStation"
        
        // Create some mock games
        let game1 = PVGame()
        game1.md5Hash = "game1"
        game1.title = "Super Mario Bros."
        game1.system = nesSystem
        game1.isFavorite = true
        game1.originalArtworkURL = "https://github.com/yakaracolombia/esp32-online-tool/blob/main/imagenes/nes.png?raw=true"
        
        let game2 = PVGame()
        game2.md5Hash = "game2"
        game2.title = "The Legend of Zelda"
        game2.system = nesSystem
        game2.isFavorite = false
        game2.originalArtworkURL = "https://github.com/yakaracolombia/esp32-online-tool/blob/main/imagenes/nes.png?raw=true"
        
        let game3 = PVGame()
        game3.md5Hash = "game3"
        game3.title = "Super Mario World"
        game3.system = snesSystem
        game3.isFavorite = true
        game3.originalArtworkURL = "http://orig09.deviantart.net/a0a9/f/2016/076/3/c/snes_logo_vector_by_windows7starterfan-d9vhz8d.png"
        
        let game4 = PVGame()
        game4.md5Hash = "game4"
        game4.title = "Sonic the Hedgehog"
        game4.system = genesisSystem
        game4.isFavorite = false
        game4.originalArtworkURL = "https://www.seekpng.com/png/full/66-669199_sega-genesis-logo-png-download-sega-3d-logo.png"
        
        let game5 = PVGame()
        game5.md5Hash = "game5"
        game5.title = "Pokémon FireRed"
        game5.system = gbaSystem
        game5.isFavorite = true
        game5.originalArtworkURL = "https://www.pngkit.com/png/full/142-1424510_source-nintendo-game-boy-advance-logo.png"
        
        let game6 = PVGame()
        game6.md5Hash = "game6"
        game6.title = "Final Fantasy VII"
        game6.system = psx
        game6.isFavorite = true
        game6.originalArtworkURL = "https://pngimg.com/uploads/sony_playstation/sony_playstation_PNG17532.png"
        
        // Add games to the collection
        games = [game1, game2, game3, game4, game5, game6]
        
        // Create recent games (in order of play)
        let recent1 = PVRecentGame()
        recent1.game = game4 // Sonic
        recent1.lastPlayedDate = Date().addingTimeInterval(-3600 * 2) // 2 hours ago
        
        let recent2 = PVRecentGame()
        recent2.game = game5 // Pokémon
        recent2.lastPlayedDate = Date().addingTimeInterval(-3600 * 5) // 5 hours ago
        
        let recent3 = PVRecentGame()
        recent3.game = game1 // Mario
        recent3.lastPlayedDate = Date().addingTimeInterval(-3600 * 10) // 10 hours ago
        
        let recent4 = PVRecentGame()
        recent4.game = game6 // FF7
        recent4.lastPlayedDate = Date().addingTimeInterval(-3600 * 24) // 1 day ago
        
        // Add recent games to the collection
        recentGames = [recent1, recent2, recent3, recent4]
    }
}

/// Real implementation of TopShelfDataDriver that uses Realm database
class RealmTopShelfDataDriver: TopShelfDataDriver {
    private let logger = OSLog(subsystem: "org.provenance-emu.provenance.topshelf", category: "RealmDriver")
    
    /// Actor to isolate Realm configuration and coordinate access
    private actor RealmActor {
        var configuration: Realm.Configuration?
        
        func setConfiguration(_ config: Realm.Configuration) {
            self.configuration = config
        }
        
        func getConfiguration() -> Realm.Configuration? {
            return configuration
        }
        
        // Instead of storing a Realm instance, we'll create a frozen copy of the objects we need
        // This allows us to safely pass them across thread boundaries
        
        func queryRecentlyPlayedGames(limit: Int) -> [PVGame] {
            guard let config = configuration else { return [] }
            
            // Create a new Realm instance for this operation
            guard let realm = try? Realm(configuration: config) else { return [] }
            
            // Get recently played games
            let recentlyPlayedGames = realm.objects(PVRecentGame.self).sorted(byKeyPath: "lastPlayedDate", ascending: false)
                .prefix(limit)
            
            // Map to actual games and freeze them so they can be used across threads
            var games: [PVGame] = []
            for recentGame in recentlyPlayedGames {
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: recentGame.game.md5Hash) {
                    // Create a detached copy by extracting the primary key and refetching later
                    games.append(game.freeze())
                }
            }
            
            return games
        }
        
        func queryFavoriteGames(limit: Int) -> [PVGame] {
            guard let config = configuration else { return [] }
            
            // Create a new Realm instance for this operation
            guard let realm = try? Realm(configuration: config) else { return [] }
            
            // Get favorite games
            let favoriteGames = realm.objects(PVGame.self).filter("isFavorite == true")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(limit)
            
            // Freeze the results so they can be used across threads
            return favoriteGames.map { $0.freeze() }
        }
        
        func queryRecentlyAddedGames(limit: Int) -> [PVGame] {
            guard let config = configuration else { return [] }
            
            // Create a new Realm instance for this operation
            guard let realm = try? Realm(configuration: config) else { return [] }
            
            // Get recently added games
            let recentlyAddedGames = realm.objects(PVGame.self).sorted(byKeyPath: "importDate", ascending: false)
                .prefix(limit)
            
            // Freeze the results so they can be used across threads
            return recentlyAddedGames.map { $0.freeze() }
        }
        
        func queryGameByID(id: String) -> PVGame? {
            guard let config = configuration else { return nil }
            
            // Create a new Realm instance for this operation
            guard let realm = try? Realm(configuration: config) else { return nil }
            
            // Get the game and freeze it so it can be used across threads
            return realm.object(ofType: PVGame.self, forPrimaryKey: id)?.freeze()
        }
        
        func getGameCount() -> Int {
            guard let config = configuration else { return 0 }
            
            // Create a new Realm instance for this operation
            guard let realm = try? Realm(configuration: config) else { return 0 }
            
            return realm.objects(PVGame.self).count
        }
    }
    
    private let realmActor = RealmActor()
    
    /// Collection of error messages for debugging
    private(set) var errorMessages: [String] = []
    
    /// Initialize the driver with the real database
    func initialize() async throws {
        do {
            // Log initialization start
            os_log("Starting Realm database initialization", log: logger, type: .debug)
            
            // Get the app group container URL
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) else {
                let error = "Could not access app group container"
                os_log("%{public}@", log: logger, type: .error, error)
                throw NSError(domain: "TopShelfDataDriver", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            os_log("App group container exists at: %{public}@", log: logger, type: .debug, containerURL.path)
            
            // On tvOS, the Realm database is stored in a Library/Caches/ subfolder
            let realmFilename = "default.realm"
            let tvOSCachesPath = containerURL.appendingPathComponent("Library/Caches/")
            let realmURL = tvOSCachesPath.appendingPathComponent(realmFilename, isDirectory: false)
            
            // Make sure the directory exists
            if !FileManager.default.fileExists(atPath: tvOSCachesPath.path) {
                os_log("Creating Library/Caches directory", log: logger, type: .debug)
                do {
                    try FileManager.default.createDirectory(at: tvOSCachesPath, withIntermediateDirectories: true)
                } catch {
                    os_log("Failed to create Library/Caches directory: %{public}@", log: logger, type: .error, error.localizedDescription)
                }
            }
            
            if FileManager.default.fileExists(atPath: realmURL.path) {
                os_log("Realm database file exists at: %{public}@", log: logger, type: .debug, realmURL.path)
            } else {
                let error = "Realm database file does not exist at: \(realmURL.path)"
                os_log("%{public}@", log: logger, type: .error, error)
                throw NSError(domain: "TopShelfDataDriver", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            // Set up the Realm configuration with the correct schema version
            var config = Realm.Configuration.defaultConfiguration
            config.fileURL = realmURL
            config.readOnly = true // Use read-only mode for TopShelf extension
            
            // Use the schema version we imported from PVLibrary
            config.schemaVersion = topShelfSchemaVersion
            os_log("Using schema version %{public}llu", log: logger, type: .debug, topShelfSchemaVersion)
            
            // Add migration block to handle schema changes
            config.migrationBlock = { _, _ in
                // Migration is handled by the main app, we just need to provide a block
                // This is a no-op since we're in read-only mode
            }
            
            // Store the configuration in the actor for potential reuse
            await realmActor.setConfiguration(config)
            
            os_log("Set up Realm configuration with URL: %{public}@", log: logger, type: .debug, realmURL.path)
            
            // Test opening a Realm with the configuration to verify it works
            let testRealm = try await Realm(configuration: config)
            os_log("Successfully opened Realm database", log: logger, type: .debug)
            
            // Verify we can access data in the Realm
            do {
                let count = await realmActor.getGameCount()
                os_log("Found %d total games in database", log: logger, type: .debug, count)
                
                if count == 0 {
                    let warning = "Realm database opened successfully but contains no games"
                    os_log("%{public}@", log: logger, type: .info, warning)
                    errorMessages.append(warning)
                }
            } catch {
                let errorMsg = "Error accessing Realm data: \(error.localizedDescription)"
                os_log("%{public}@", log: logger, type: .error, errorMsg)
                errorMessages.append(errorMsg)
                throw error
            }
        } catch {
            os_log("Error initializing Realm database: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw error
        }
    }
    
    /// Get recently played games
    func getRecentlyPlayedGames(limit: Int) async -> [PVGame] {
        do {
            let games = await realmActor.queryRecentlyPlayedGames(limit: limit)
            os_log("Found %d recently played games", log: logger, type: .debug, games.count)
            return games
        } catch {
            let errorMsg = "Error getting recently played games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get favorite games
    func getFavoriteGames(limit: Int) async -> [PVGame] {
        do {
            let favoriteGames = await realmActor.queryFavoriteGames(limit: limit)
            os_log("Found %d favorite games", log: logger, type: .debug, favoriteGames.count)
            return favoriteGames
        } catch {
            let errorMsg = "Error getting favorite games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get recently added games
    func getRecentlyAddedGames(limit: Int) async -> [PVGame] {
        do {
            // Try to get total game count first
            let count = await realmActor.getGameCount()
            os_log("Found %d total games in database", log: logger, type: .debug, count)
            
            if count == 0 {
                let warning = "Database contains no games"
                errorMessages.append(warning)
                os_log("%{public}@", log: logger, type: .info, warning)
            }
            
            // Get recently added games
            let recentlyAddedGames = await realmActor.queryRecentlyAddedGames(limit: limit)
            os_log("Found %d recently added games", log: logger, type: .debug, recentlyAddedGames.count)
            return recentlyAddedGames
        } catch {
            let errorMsg = "Error getting recently added games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get a game by ID
    func getGame(byID id: String) async -> PVGame? {
        do {
            return await realmActor.queryGameByID(id: id)
        } catch {
            let errorMsg = "Error getting game by ID: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return nil
        }
    }
}
