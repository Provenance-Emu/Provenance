//
//  SpotlightMockDriver.swift
//  Spotlight
//
//  Created by Joseph Mattiello on 4/16/25.
//  Copyright © 2025 Joseph Mattiello. All rights reserved.
//

import Foundation
import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift
import UniformTypeIdentifiers

/// Protocol for Spotlight data drivers
protocol SpotlightDataDriver {
    /// Initialize the driver
    func initialize() async throws
    
    /// Get a game by MD5 hash
    func getGame(byMD5 md5: String) throws -> PVGame?
    
    /// Get all games
    func getAllGames() throws -> [PVGame]
    
    /// Get games matching specific identifiers
    func getGames(withIdentifiers identifiers: [String]) throws -> [PVGame]
    
    /// Get any error messages from the driver
    var errorMessages: [String] { get }
}

/// Mock implementation of SpotlightDataDriver for development and testing
class MockSpotlightDataDriver: SpotlightDataDriver {
    /// Collection of error messages for debugging
    private(set) var errorMessages: [String] = []
    
    /// Collection of mock games
    private var games: [PVGame] = []
    
    /// Initialize the driver with mock data
    func initialize() async throws {
        ILOG("MockSpotlightDriver: Initializing with mock data")
        createMockData()
    }
    
    /// Get a game by MD5 hash
    func getGame(byMD5 md5: String) throws -> PVGame? {
        ILOG("MockSpotlightDriver: Looking up game with MD5: \(md5)")
        return games.first { $0.md5Hash == md5 }
    }
    
    /// Get all games
    func getAllGames() throws -> [PVGame] {
        ILOG("MockSpotlightDriver: Returning all \(games.count) mock games")
        return games
    }
    
    /// Get games matching specific identifiers
    func getGames(withIdentifiers identifiers: [String]) throws -> [PVGame] {
        ILOG("MockSpotlightDriver: Looking up games with identifiers: \(identifiers)")
        return games.filter { identifiers.contains($0.md5Hash) }
    }
    
    /// Create mock data for testing
    private func createMockData() {
        // Create some mock systems
        let nesSystem = PVSystem()
        nesSystem.identifier = "NES"
        nesSystem.name = "Nintendo Entertainment System"
        nesSystem.manufacturer = "Nintendo"
        
        let snesSystem = PVSystem()
        snesSystem.identifier = "SNES"
        snesSystem.name = "Super Nintendo"
        snesSystem.manufacturer = "Nintendo"
        
        let genesisSystem = PVSystem()
        genesisSystem.identifier = "Genesis"
        genesisSystem.name = "Sega Genesis"
        genesisSystem.manufacturer = "Sega"
        
        let gbaSystem = PVSystem()
        gbaSystem.identifier = "GBA"
        gbaSystem.name = "Game Boy Advance"
        gbaSystem.manufacturer = "Nintendo"
        
        let psxSystem = PVSystem()
        psxSystem.identifier = "PSX"
        psxSystem.name = "PlayStation"
        psxSystem.manufacturer = "Sony"
        
        // Create some mock games
        let game1 = PVGame()
        game1.md5Hash = "game1"
        game1.title = "Super Mario Bros."
        game1.system = nesSystem
        game1.isFavorite = true
        game1.gameDescription = "The classic platformer that defined a generation"
        game1.developer = "Nintendo"
        game1.publishDate = "1985"
        game1.lastPlayed = Date().addingTimeInterval(-86400 * 2) // 2 days ago
        
        let game2 = PVGame()
        game2.md5Hash = "game2"
        game2.title = "The Legend of Zelda"
        game2.system = nesSystem
        game2.isFavorite = false
        game2.gameDescription = "Epic adventure through the land of Hyrule"
        game2.developer = "Nintendo"
        game2.publishDate = "1986"
        game2.lastPlayed = Date().addingTimeInterval(-86400 * 5) // 5 days ago
        
        let game3 = PVGame()
        game3.md5Hash = "game3"
        game3.title = "Super Mario World"
        game3.system = snesSystem
        game3.isFavorite = true
        game3.gameDescription = "Mario's 16-bit adventure with Yoshi"
        game3.developer = "Nintendo"
        game3.publishDate = "1990"
        game3.lastPlayed = Date().addingTimeInterval(-86400 * 1) // 1 day ago
        
        let game4 = PVGame()
        game4.md5Hash = "game4"
        game4.title = "Sonic the Hedgehog"
        game4.system = genesisSystem
        game4.isFavorite = false
        game4.gameDescription = "Sega's speedy mascot's debut game"
        game4.developer = "Sonic Team"
        game4.publishDate = "1991"
        game4.lastPlayed = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        
        let game5 = PVGame()
        game5.md5Hash = "game5"
        game5.title = "Pokémon FireRed"
        game5.system = gbaSystem
        game5.isFavorite = true
        game5.gameDescription = "Remake of the original Pokémon Red"
        game5.developer = "Game Freak"
        game5.publishDate = "2004"
        game5.lastPlayed = Date().addingTimeInterval(-86400 * 3) // 3 days ago
        
        let game6 = PVGame()
        game6.md5Hash = "game6"
        game6.title = "Final Fantasy VII"
        game6.system = psxSystem
        game6.isFavorite = true
        game6.gameDescription = "Cloud Strife's epic journey"
        game6.developer = "Square"
        game6.publishDate = "1997"
        game6.lastPlayed = Date().addingTimeInterval(-86400 * 0.5) // 12 hours ago
        
        // Add games to the collection
        games = [game1, game2, game3, game4, game5, game6]
        
        ILOG("MockSpotlightDriver: Created \(games.count) mock games")
    }
}
