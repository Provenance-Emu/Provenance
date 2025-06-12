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
    // Collection of error messages for debugging
    private var errorMessages: [String] = []
    private var database: RomDatabase?
    
    public override init() {
        super.init()
        print("TopShelf: ServiceProvider initializing")
        print("TopShelf: App Group ID: \(PVAppGroupId)")
        
        // Try to initialize Realm, but don't let it prevent us from showing something
        do {
            setupRealm()
        } catch {
            print("TopShelf: Error in init: \(error)")
            errorMessages.append("Init error: \(error.localizedDescription)")
        }
    }
    
    private func setupRealm() {
        // Configure Realm for the extension
        do {
            print("TopShelf: Checking if app groups are supported")
            print("TopShelf: RealmConfiguration.supportsAppGroups = \(RealmConfiguration.supportsAppGroups)")
            
            if let container = RealmConfiguration.appGroupContainer {
                print("TopShelf: App group container exists at: \(container.path)")
            } else {
                print("TopShelf: App group container is nil")
                errorMessages.append("App group container is nil")
            }
            
            if let path = RealmConfiguration.appGroupPath {
                print("TopShelf: App group path exists at: \(path.path)")
            } else {
                print("TopShelf: App group path is nil")
                errorMessages.append("App group path is nil")
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
            
            // Use the existing RealmConfiguration from PVLibrary
            print("TopShelf: Setting default Realm configuration")
            RealmConfiguration.setDefaultRealmConfig()
            
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
            }
            
            // Initialize the database
            print("TopShelf: Initializing Realm")
            let realm = try Realm()
            print("TopShelf: Realm configuration: \(realm.configuration)")
            realm.refresh()
            
            // Create the database instance
            print("TopShelf: Getting RomDatabase.sharedInstance")
            database = RomDatabase.sharedInstance
            
            if database != nil {
                print("TopShelf: Successfully initialized Realm database")
            } else {
                let message = "Failed to get RomDatabase.sharedInstance"
                print("TopShelf: \(message)")
                errorMessages.append(message)
            }
        } catch {
            let errorMessage = "Failed to initialize Realm: \(error.localizedDescription)"
            print("TopShelf: \(errorMessage)")
            errorMessages.append(errorMessage)
        }
    }

    // MARK: - TVTopShelfContentProvider protocol

    public var topShelfContent: TVTopShelfContent {
        print("TopShelf: topShelfContent requested")
        
        // Always show something, even if it's just a debug message
        // This ensures we know the extension is loading at all
        return createDebugContent()
        

    }

    // MARK: - Private Helpers
    
    // MARK: - Debug Content
    
    private func createDebugContent() -> TVTopShelfContent {
        // Create debug items
        var items: [TVTopShelfSectionedItem] = []
        
        // Add a basic debug item that will always show up
        let debugItem = TVTopShelfSectionedItem(identifier: "debug_basic")
        debugItem.title = "Provenance TopShelf - Debug Mode"
        debugItem.imageShape = .square
        items.append(debugItem)
        
        // Add app group info
        let appGroupItem = TVTopShelfSectionedItem(identifier: "debug_appgroup")
        appGroupItem.title = "App Group ID: \(PVAppGroupId)"
        appGroupItem.imageShape = .square
        items.append(appGroupItem)
        
        // Add any error messages
        for (index, message) in errorMessages.enumerated() {
            let errorItem = TVTopShelfSectionedItem(identifier: "error_\(index)")
            errorItem.title = "Error: \(message)"
            errorItem.imageShape = .square
            items.append(errorItem)
        }
        
        // Create a section for debug info
        let debugSection = TVTopShelfItemCollection(items: items)
        debugSection.title = "Provenance TopShelf Debug Info"
        
        return TVTopShelfSectionedContent(sections: [debugSection])
    }
}
