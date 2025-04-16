//
//  SpotlightHelper.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/16/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CoreSpotlight
import PVSupport
import RealmSwift

/// Helper class for Spotlight operations
public class SpotlightHelper {
    
    /// Shared instance for easy access
    public static let shared = SpotlightHelper()
    
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"
    
    private init() {}
    
    /// Force reindex all Provenance content in Spotlight
    /// - Parameter completion: Optional completion handler called when reindexing is complete
    public func forceReindexAll(completion: (() -> Void)? = nil) {
        ILOG("Starting Spotlight reindexing for all Provenance content")
        
        // Get the default searchable index
        let searchableIndex = CSSearchableIndex.default()
        
        // Delete all Provenance items from the index first
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                ELOG("Error deleting existing Spotlight items: \(error)")
            } else {
                ILOG("Successfully deleted existing Spotlight items")
            }
            
            // Now reindex all games and save states
            Task {
                do {
                    try await self.reindexAllGames()
                    try await self.reindexAllSaveStates()
                    ILOG("Successfully reindexed Spotlight items")
                } catch {
                    ELOG("Error during Spotlight reindexing: \(error)")
                }
                
                // Call completion handler if provided
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    /// Reindex all games in Spotlight
    private func reindexAllGames() async throws {
        ILOG("Reindexing all games in Spotlight")
        
        // Get the default searchable index
        let searchableIndex = CSSearchableIndex.default()
        
        // Create a batch processor to handle multiple items at once
        var pendingItems: [CSSearchableItem] = []
        let batchSize = 50 // Smaller batch size for more frequent updates
        var totalIndexed = 0
        
        // Function to process a batch of items
        func processBatch() async throws {
            guard !pendingItems.isEmpty else { return }
            
            try await searchableIndex.indexSearchableItems(pendingItems)
            totalIndexed += pendingItems.count
            ILOG("Indexed batch of \(pendingItems.count) games (Total: \(totalIndexed))")
            pendingItems.removeAll(keepingCapacity: true)
        }
        
        // Get Realm configuration
        let config = RealmConfiguration.realmConfig
        let realm = try await Realm(configuration: config)
        
        // Get all games from the database
        let allGames = realm.objects(PVGame.self)
        ILOG("Found \(allGames.count) games to index")
        
        // Process each game
        for game in allGames {
            // Create a frozen copy of the game to safely use across threads
            let frozenGame = game.freeze()
            
            // Create the searchable item
            let attributeSet = frozenGame.spotlightContentSet
            
            // Add system information if available
            if let system = frozenGame.system {
                attributeSet.contentType = "\(system.manufacturer) \(system.name)"
            }
            
            // Add keywords for better searchability
            if var keywords = attributeSet.keywords as? [String] {
                if let systemName = frozenGame.system?.name, !keywords.contains(systemName) {
                    keywords.append(systemName)
                }
                if let manufacturer = frozenGame.system?.manufacturer, !keywords.contains(manufacturer) {
                    keywords.append(manufacturer)
                }
                attributeSet.keywords = keywords
            }
            
            // Create the searchable item
            let item = CSSearchableItem(
                uniqueIdentifier: "org.provenance-emu.game.\(frozenGame.md5Hash)",
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            
            pendingItems.append(item)
            
            // Process batch if we've reached the batch size
            if pendingItems.count >= batchSize {
                try await processBatch()
            }
        }
        
        // Process any remaining items
        try await processBatch()
    }
    
    /// Reindex all save states in Spotlight
    private func reindexAllSaveStates() async throws {
        ILOG("Reindexing all save states in Spotlight")
        
        // Get the default searchable index
        let searchableIndex = CSSearchableIndex.default()
        
        // Create a batch processor to handle multiple items at once
        var pendingItems: [CSSearchableItem] = []
        let batchSize = 50 // Smaller batch size for more frequent updates
        var totalIndexed = 0
        
        // Function to process a batch of items
        func processBatch() async throws {
            guard !pendingItems.isEmpty else { return }
            
            try await searchableIndex.indexSearchableItems(pendingItems)
            totalIndexed += pendingItems.count
            ILOG("Indexed batch of \(pendingItems.count) save states (Total: \(totalIndexed))")
            pendingItems.removeAll(keepingCapacity: true)
        }
        
        // Get Realm configuration
        let config = RealmConfiguration.realmConfig
        let realm = try await Realm(configuration: config)
        
        // Get all save states from the database
        let allSaveStates = realm.objects(PVSaveState.self)
        ILOG("Found \(allSaveStates.count) save states to index")
        
        // Process each save state
        for saveState in allSaveStates {
            // Create a frozen copy of the save state to safely use across threads
            let frozenSaveState = saveState.freeze()
            
            // Get the associated game
            guard let game = frozenSaveState.game else { continue }
            
            // Create attribute set
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
            attributeSet.displayName = "Save State: \(game.title)"
            attributeSet.contentDescription = "Save state for \(game.title) on \(game.system?.name ?? "Unknown System")"
            
            // Add date information
            attributeSet.contentCreationDate = frozenSaveState.date
            attributeSet.contentModificationDate = frozenSaveState.date
            
            // Add keywords
            var keywords = ["save state", "saved game", "provenance", "emulator"]
            if let systemName = game.system?.name {
                keywords.append(systemName)
            }
            attributeSet.keywords = keywords
            
            // Create searchable item
            let item = CSSearchableItem(
                uniqueIdentifier: "org.provenance-emu.savestate.\(frozenSaveState.id)",
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            
            pendingItems.append(item)
            
            // Process batch if we've reached the batch size
            if pendingItems.count >= batchSize {
                try await processBatch()
            }
        }
        
        // Process any remaining items
        try await processBatch()
    }
}
