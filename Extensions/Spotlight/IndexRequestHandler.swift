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

public enum SpotlightError: Error {
    case appGroupsNotSupported
    case dontHandleDatatype
    case notFound
    case realmError(Error)
}

public final class IndexRequestHandler: CSIndexExtensionRequestHandler {
    /// Domain identifier for all Provenance items
    private let domainIdentifier = "org.provenance-emu.games"
    
    public override init() {
        super.init()
        
        if RealmConfiguration.supportsAppGroups {
            RealmConfiguration.setDefaultRealmConfig()
        } else {
            WLOG("App Groups not supported during Spotlight indexer initialization")
        }
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing all searchable items")
        
        if RealmConfiguration.supportsAppGroups {
            let database = RomDatabase.sharedInstance
            let allGames = database.all(PVGame.self)
            
            if allGames.isEmpty {
                WLOG("Spotlight: No games found to index")
            } else {
                ILOG("Spotlight: Found \(allGames.count) games to index")
                indexResults(allGames)
            }
        } else {
            WLOG("Spotlight: App Groups not setup, cannot reindex")
        }
        
        acknowledgementHandler()
    }
    
    public override func searchableIndex(_: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        ILOG("Spotlight: Reindexing items with identifiers: \(identifiers)")
        
        if RealmConfiguration.supportsAppGroups {
            let database = RomDatabase.sharedInstance
            let allGamesMatching = database.all(PVGame.self, filter: NSPredicate(format: "md5Hash IN %@", identifiers))
            
            if allGamesMatching.isEmpty {
                WLOG("Spotlight: No matching games found for identifiers")
            } else {
                ILOG("Spotlight: Found \(allGamesMatching.count) matching games to reindex")
                indexResults(allGamesMatching)
            }
        } else {
            WLOG("Spotlight: App Groups not setup, cannot reindex")
        }
        
        acknowledgementHandler()
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
        
        if !RealmConfiguration.supportsAppGroups {
            ELOG("Spotlight: App Groups not supported")
            throw SpotlightError.appGroupsNotSupported
        }
        
        // We're assuming the typeIndentifier is the game one since that's all we've been using so far
        if typeIdentifier == (kUTTypeImage as String) {
            // Extract MD5 hash from the identifier (format: org.provenance-emu.game.MD5HASH)
            let md5 = itemIdentifier.components(separatedBy: ".").last ?? ""
            
            do {
                let realm = try Realm()
                if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5), let artworkURL = game.pathOfCachedImage {
                    ILOG("Spotlight: Found artwork for game with md5: \(md5)")
                    return artworkURL
                } else {
                    WLOG("Spotlight: No artwork found for game with md5: \(md5)")
                    throw SpotlightError.notFound
                }
            } catch let error as Realm.Error {
                ELOG("Spotlight: Realm error when getting file URL: \(error)")
                throw SpotlightError.realmError(error)
            } catch {
                ELOG("Spotlight: Generic error when getting file URL: \(error)")
                throw error
            }
        } else {
            WLOG("Spotlight: Unsupported type identifier: \(typeIdentifier)")
            throw SpotlightError.dontHandleDatatype
        }
    }
    
    private func indexResults(_ results: Results<PVGame>) {
        ILOG("Spotlight: Indexing \(results.count) games")
        
        let items: [CSSearchableItem] = results.compactMap({ (game) -> CSSearchableItem? in
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
