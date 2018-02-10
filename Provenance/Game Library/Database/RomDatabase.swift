//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import Realm

public extension RLMRealmConfiguration {

    
    class public var supportsAppGroups : Bool {
        return !PVAppGroupId.isEmpty && RLMRealmConfiguration.appGroupContainer != nil
    }
    
    class public var appGroupContainer : URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
    }
    
    class public var appGroupPath : String? {
        guard let appGroupContainer = RLMRealmConfiguration.appGroupContainer else {
            return nil
        }

        let appGroupPath = appGroupContainer.appendingPathComponent("Library/Caches/").absoluteString
        return appGroupPath
    }
}

public final class RomDatabase : NSObject {
    
    public static var sharedInstance : RomDatabase =  {
        setDefaultRealmConfig()
        return RomDatabase()
    }()
    
    private class func setDefaultRealmConfig() {
        let config = RomDatabase.realmConfig
        RLMRealmConfiguration.setDefault(config)
    }
    
    // For multi-threading
    public static func temporaryDatabaseContext() -> RomDatabase {
        return RomDatabase()
    }
    
    private static var realmConfig : RLMRealmConfiguration = {
        let config = RLMRealmConfiguration()
        #if TARGET_OS_TV
            var path: String? = nil
            if RLMRealmConfiguration.supportsAppGroups() {
                path = RLMRealmConfiguration.appGroupPath()
            }
            else {
                let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
                path = paths.first
            }
        #else
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let path: String? = paths.first
        #endif
        let pathString = URL(fileURLWithPath: path!).appendingPathComponent("default.realm").path
        config.path = pathString
        // Bump schema version to migrate new PVGame property, isFavorite
        config.schemaVersion = 1
        config.migrationBlock = nil
        //        {(_ migration: RLMMigration, _ oldSchemaVersion: UInt64) -> Void in
        //            // Nothing to do, Realm handles migration automatically when we set an empty migration block
        //        }
        
        return config
    }()

    fileprivate var realm : RLMRealm
    
    override init() {
        self.realm = RLMRealm.default()

        super.init()
    }
}

// MARK: - Queries
public extension RomDatabase {
    public var allGames : RLMResults<PVGame> {
        return PVGame.allObjects(in: self.realm) as! RLMResults<PVGame>
    }
    
    public func allGames(sortedByKey sortKey: String = "title", ascending: Bool = true) -> RLMResults<PVGame> {
        return allGames.sortedResults(usingProperty: sortKey, ascending: ascending)
    }
    
    // This should be a generic, but can't be for Obj-C
    public func objectsOfType(_ type : AnyClass, predicate: NSPredicate) -> RLMResults<RLMObject> {
        return type.objects(in: self.realm, with: predicate)
    }
    
    // Can use keyPaths here - Probbly not correct i nthis form
    public func all<T:RLMObject>(where keyPath: KeyPath<T, AnyKeyPath>, value : String) -> RLMResults<T> {
        return T.objects(in: self.realm, with: NSPredicate(format: "\(keyPath) == %@", value)) as! RLMResults<T>
    }
}

// MARK: - Update
public extension RomDatabase {
    public func writeTransaction(_ block: () -> Void) throws {
        realm.beginWriteTransaction()
        block()
        try realm.commitWriteTransaction()
    }
    
    public func add(object: RLMObject) throws {
        realm.beginWriteTransaction()
        realm.add(object)
        try realm.commitWriteTransaction()
    }
    
    public func add<T:NSFastEnumeration>(objects: T) throws {
        realm.beginWriteTransaction()
        realm.addObjects(objects)
        try realm.commitWriteTransaction()
    }
    
    public func deleteAllObjects() throws {
        realm.beginWriteTransaction()
        realm.deleteAllObjects()
        try realm.commitWriteTransaction()
    }
    
    public func delete(object: RLMObject) throws {
        realm.beginWriteTransaction()
        realm.delete(object)
        try realm.commitWriteTransaction()
    }
}

public extension RomDatabase {
    public func refresh() {
        realm.refresh()
    }
}
