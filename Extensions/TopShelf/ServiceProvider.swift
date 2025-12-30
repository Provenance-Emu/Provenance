//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
import Foundation
import PVLibrary
import PVSupport
import RealmSwift
import TVServices

/** Enabling Top Shelf

 1. Enable App Groups on the TopShelf target, and specify an App Group ID
 Provenance Project -> TopShelf Target -> Capabilities Section -> App Groups
 2. Enable App Groups on the Provenance TV target, using the same App Group ID
 3. Define the value for `PVAppGroupId` in `PVAppConstants.m` to that App Group ID

 */

@objc(ServiceProvider)
public final class ServiceProvider: TVTopShelfContentProvider {
    /// Collection of error messages for debugging
    private var errorMessages: [String] = []
    
    /// Maximum number of games to show in each section
    private let maxGamesPerSection = 10
    
    /// Flag indicating if Realm was successfully initialized
    private var realmInitialized = false

    public override init() {
        super.init()
        print("TopShelf: ServiceProvider initializing")
        print("TopShelf: App Group ID: \(PVAppGroupId)")

        // Try to initialize Realm
        setupRealm()
    }

    private func setupRealm() {
        print("TopShelf: Checking if app groups are supported")
        print("TopShelf: RealmConfiguration.supportsAppGroups = \(RealmConfiguration.supportsAppGroups)")

        if let container = RealmConfiguration.appGroupContainer {
            print("TopShelf: App group container exists at: \(container.path)")
        } else {
            print("TopShelf: App group container is nil")
            errorMessages.append("App group container is nil")
            return
        }

        if let path = RealmConfiguration.appGroupPath {
            print("TopShelf: App group path exists at: \(path.path)")
        } else {
            print("TopShelf: App group path is nil")
            errorMessages.append("App group path is nil")
            return
        }

        // Make sure we're using app groups
        guard RealmConfiguration.supportsAppGroups,
              let appGroupPath = RealmConfiguration.appGroupPath else {
            let message = "App doesn't support groups. Check \(PVAppGroupId) is a valid group id"
            print("TopShelf: \(message)")
            errorMessages.append(message)
            return
        }

        print("TopShelf: Setting up Realm with app group path: \(appGroupPath.path)")

        // Check if the Realm file exists
        let realmFilename = "default.realm"
        let realmURL = appGroupPath.appendingPathComponent(realmFilename, isDirectory: false)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: realmURL.path) {
            print("TopShelf: Realm database file exists at: \(realmURL.path)")
        } else {
            let message = "Realm database file does NOT exist at: \(realmURL.path)"
            print("TopShelf: \(message)")
            errorMessages.append(message)
            return
        }

        // Set the default Realm configuration using PVLibrary's shared configuration
        print("TopShelf: Setting default Realm configuration")
        RealmConfiguration.setDefaultRealmConfig()

        // Verify database is accessible using RomDatabase.sharedInstance
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            realm.refresh()
            let gameCount = realm.objects(PVGame.self).count
            print("TopShelf: Successfully initialized Realm. Found \(gameCount) games")
            
            if gameCount == 0 {
                errorMessages.append("No games found in database")
            }
            
            realmInitialized = true
        } catch {
            let errorMessage = "Failed to initialize Realm: \(error.localizedDescription)"
            print("TopShelf: \(errorMessage)")
            errorMessages.append(errorMessage)
        }
    }

    // MARK: - TVTopShelfContentProvider protocol

    public override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        print("TopShelf: loadTopShelfContent requested")
        
        // If Realm wasn't initialized, show debug content
        guard realmInitialized else {
            print("TopShelf: Realm not initialized, showing debug content")
            return createDebugContent()
        }
        
        // Create sections for different types of games
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        
        // Add recently played games section
        if let recentlyPlayedSection = createRecentlyPlayedSection() {
            sections.append(recentlyPlayedSection)
            print("TopShelf: Added recently played section")
        }
        
        // Add favorites section
        if let favoritesSection = createFavoriteSection() {
            sections.append(favoritesSection)
            print("TopShelf: Added favorites section")
        }
        
        // Add recently added games section
        if let recentlyAddedSection = createRecentlyAddedSection() {
            sections.append(recentlyAddedSection)
            print("TopShelf: Added recently added section")
        }
        
        // If no sections were created, show debug content
        if sections.isEmpty {
            print("TopShelf: No sections created, showing debug content")
            return createDebugContent()
        }
        
        return TVTopShelfSectionedContent(sections: sections)
    }

    // MARK: - Section Creation
    
    private func createRecentlyPlayedSection() -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let recentlyPlayedGames = realm.objects(PVRecentGame.self)
                .sorted(byKeyPath: "lastPlayedDate", ascending: false)
                .prefix(maxGamesPerSection)
            
            let items = recentlyPlayedGames.compactMap { recentGame -> TVTopShelfSectionedItem? in
                guard let game = recentGame.game else { return nil }
                return game.topShelfItem()
            }
            
            if items.isEmpty {
                print("TopShelf: No recently played games found")
                return nil
            }
            
            let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: Array(items))
            collection.title = "Recently Played"
            return collection
        } catch {
            print("TopShelf: Error creating recently played section: \(error)")
            return nil
        }
    }
    
    private func createFavoriteSection() -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let favoriteGames = realm.objects(PVGame.self)
                .filter("isFavorite == true")
                .sorted(byKeyPath: "title", ascending: true)
                .prefix(maxGamesPerSection)
            
            let items = favoriteGames.map { $0.topShelfItem() }
            
            if items.isEmpty {
                print("TopShelf: No favorite games found")
                return nil
            }
            
            let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: Array(items))
            collection.title = "Favorites"
            return collection
        } catch {
            print("TopShelf: Error creating favorites section: \(error)")
            return nil
        }
    }
    
    private func createRecentlyAddedSection() -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        do {
            let database = RomDatabase.sharedInstance
            let realm = database.realm
            
            let recentlyAddedGames = realm.objects(PVGame.self)
                .sorted(byKeyPath: "importDate", ascending: false)
                .prefix(maxGamesPerSection)
            
            let items = recentlyAddedGames.map { $0.topShelfItem() }
            
            if items.isEmpty {
                print("TopShelf: No recently added games found")
                return nil
            }
            
            let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: Array(items))
            collection.title = "Recently Added"
            return collection
        } catch {
            print("TopShelf: Error creating recently added section: \(error)")
            return nil
        }
    }

    // MARK: - Debug Content

    private func createDebugContent() -> TVTopShelfContent {
        var items: [TVTopShelfSectionedItem] = []

        let debugItem = TVTopShelfSectionedItem(identifier: "debug_basic")
        debugItem.title = "Provenance TopShelf"
        debugItem.imageShape = .square
        
        // Add a deep link to open the app
        if let url = URL(string: "provenance://") {
            debugItem.playAction = TVTopShelfAction(url: url)
        }
        items.append(debugItem)

        // Add app group info
        let appGroupItem = TVTopShelfSectionedItem(identifier: "debug_appgroup")
        appGroupItem.title = "App Group: \(PVAppGroupId)"
        appGroupItem.imageShape = .square
        items.append(appGroupItem)

        // Add any error messages
        for (index, message) in errorMessages.enumerated() {
            let errorItem = TVTopShelfSectionedItem(identifier: "error_\(index)")
            errorItem.title = "Error: \(message)"
            errorItem.imageShape = .square
            items.append(errorItem)
        }

        let debugSection = TVTopShelfItemCollection(items: items)
        debugSection.title = "Provenance TopShelf Debug"

        return TVTopShelfSectionedContent(sections: [debugSection])
    }
}
