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
    private(set) var errorMessages: [String] = []
    private var games: [PVGame] = []
    private var recentGames: [PVRecentGame] = []
    
    func initialize() async throws {
        createMockData()
    }
    
    func getRecentlyPlayedGames(limit: Int) -> [PVGame] {
        return Array(recentGames.prefix(limit).compactMap { recentGame in
            return games.first { $0.md5Hash == recentGame.game.md5Hash }
        })
    }
    
    func getFavoriteGames(limit: Int) -> [PVGame] {
        return Array(games.filter { $0.isFavorite }.sorted { $0.title < $1.title }.prefix(limit))
    }
    
    func getRecentlyAddedGames(limit: Int) -> [PVGame] {
        return Array(games.sorted { $0.importDate > $1.importDate }.prefix(limit))
    }
    
    func getGame(byID id: String) -> PVGame? {
        return games.first { $0.md5Hash == id }
    }
    
    private func createMockData() {
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
        
        games = [game1, game2, game3, game4, game5, game6]
        
        let recent1 = PVRecentGame()
        recent1.game = game4
        recent1.lastPlayedDate = Date().addingTimeInterval(-3600 * 2)
        
        let recent2 = PVRecentGame()
        recent2.game = game5
        recent2.lastPlayedDate = Date().addingTimeInterval(-3600 * 5)
        
        let recent3 = PVRecentGame()
        recent3.game = game1
        recent3.lastPlayedDate = Date().addingTimeInterval(-3600 * 10)
        
        let recent4 = PVRecentGame()
        recent4.game = game6
        recent4.lastPlayedDate = Date().addingTimeInterval(-3600 * 24)
        
        recentGames = [recent1, recent2, recent3, recent4]
    }
}

/// Real implementation of TopShelfDataDriver that uses shared RomDatabase
class RealmTopShelfDataDriver: TopShelfDataDriver {
    private let logger = OSLog(subsystem: "org.provenance-emu.provenance.topshelf", category: "RealmDriver")
    
    /// Collection of error messages for debugging
    private(set) var errorMessages: [String] = []
    
    /// Initialize the driver using the shared RomDatabase configuration
    func initialize() async throws {
        os_log("Starting Realm database initialization using shared RomDatabase", log: logger, type: .debug)
        
        // Check if app groups are supported
        guard RealmConfiguration.supportsAppGroups else {
            let error = "App Groups not supported. Check that \(PVAppGroupId) is a valid group id"
            os_log("%{public}@", log: logger, type: .error, error)
            errorMessages.append(error)
            throw NSError(domain: "TopShelfDataDriver", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        os_log("App Groups supported, configuring Realm", log: logger, type: .debug)
        
        // Log app group container info
        if let container = RealmConfiguration.appGroupContainer {
            os_log("App group container: %{public}@", log: logger, type: .debug, container.path)
        }
        
        if let appGroupPath = RealmConfiguration.appGroupPath {
            os_log("App group path: %{public}@", log: logger, type: .debug, appGroupPath.path)
            
            // Check if Realm file exists
            let realmURL = appGroupPath.appendingPathComponent("default.realm", isDirectory: false)
            if FileManager.default.fileExists(atPath: realmURL.path) {
                os_log("Realm database file exists at: %{public}@", log: logger, type: .debug, realmURL.path)
            } else {
                let warning = "Realm database file does not exist at: \(realmURL.path)"
                os_log("%{public}@", log: logger, type: .error, warning)
                errorMessages.append(warning)
                throw NSError(domain: "TopShelfDataDriver", code: 2, userInfo: [NSLocalizedDescriptionKey: warning])
            }
        }
        
        // Set the default Realm configuration using PVLibrary's shared configuration
        RealmConfiguration.setDefaultRealmConfig()
        os_log("Set default Realm configuration from PVLibrary", log: logger, type: .debug)
        
        // Verify database is accessible using RomDatabase.sharedInstance
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            let gameCount = realm.objects(PVGame.self).count
            os_log("Successfully connected to shared Realm database. Found %d games", log: logger, type: .debug, gameCount)
            
            if gameCount == 0 {
                let warning = "Realm database opened successfully but contains no games"
                os_log("%{public}@", log: logger, type: .info, warning)
                errorMessages.append(warning)
            }
        } catch {
            let errorMsg = "Error accessing shared Realm database: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            throw error
        }
    }
    
    /// Get recently played games using shared RomDatabase
    func getRecentlyPlayedGames(limit: Int) async -> [PVGame] {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let recentlyPlayedGames = realm.objects(PVRecentGame.self)
                .sorted(byKeyPath: "lastPlayedDate", ascending: false)
                .prefix(limit)
            
            // Map to actual games and freeze them for thread safety
            let games = recentlyPlayedGames.compactMap { recentGame -> PVGame? in
                guard let game = recentGame.game else { return nil }
                return game.freeze()
            }
            
            os_log("Found %d recently played games", log: logger, type: .debug, games.count)
            return Array(games)
        } catch {
            let errorMsg = "Error getting recently played games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get favorite games using shared RomDatabase
    func getFavoriteGames(limit: Int) async -> [PVGame] {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let favoriteGames = realm.objects(PVGame.self)
                .filter("isFavorite == true")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(limit)
            
            // Freeze the results for thread safety
            let games = favoriteGames.map { $0.freeze() }
            
            os_log("Found %d favorite games", log: logger, type: .debug, games.count)
            return Array(games)
        } catch {
            let errorMsg = "Error getting favorite games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get recently added games using shared RomDatabase
    func getRecentlyAddedGames(limit: Int) async -> [PVGame] {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let gameCount = realm.objects(PVGame.self).count
            os_log("Total games in database: %d", log: logger, type: .debug, gameCount)
            
            if gameCount == 0 {
                let warning = "Database contains no games"
                if !errorMessages.contains(warning) {
                    errorMessages.append(warning)
                }
                os_log("%{public}@", log: logger, type: .info, warning)
            }
            
            let recentlyAddedGames = realm.objects(PVGame.self)
                .sorted(byKeyPath: "importDate", ascending: false)
                .prefix(limit)
            
            // Freeze the results for thread safety
            let games = recentlyAddedGames.map { $0.freeze() }
            
            os_log("Found %d recently added games", log: logger, type: .debug, games.count)
            return Array(games)
        } catch {
            let errorMsg = "Error getting recently added games: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return []
        }
    }
    
    /// Get a game by ID using shared RomDatabase
    func getGame(byID id: String) async -> PVGame? {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            // Get the game and freeze it for thread safety
            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) {
                return game.freeze()
            }
            return nil
        } catch {
            let errorMsg = "Error getting game by ID: \(error.localizedDescription)"
            os_log("%{public}@", log: logger, type: .error, errorMsg)
            errorMessages.append(errorMsg)
            return nil
        }
    }
}
