//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

public class RealmConfiguration {
    class public var supportsAppGroups : Bool {
        return !PVAppGroupId.isEmpty && RealmConfiguration.appGroupContainer != nil
    }
    
    class public var appGroupContainer : URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
    }
    
    class public var appGroupPath : String? {
        guard let appGroupContainer = RealmConfiguration.appGroupContainer else {
            return nil
        }

        let appGroupPath = appGroupContainer.appendingPathComponent("Library/Caches/").path
        return appGroupPath
    }
    
    class public func setDefaultRealmConfig() {
        let config = RealmConfiguration.realmConfig
        Realm.Configuration.defaultConfiguration = config
    }
    
    private static var realmConfig : Realm.Configuration = {
        #if os(tvOS)
            var path: String? = nil
            if RealmConfiguration.supportsAppGroups {
                path = RealmConfiguration.appGroupPath
            }
            else {
                let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
                path = paths.first
            }
        #else
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let path: String? = paths.first
        #endif
        let realmURL = URL(fileURLWithPath: path!).appendingPathComponent("default.realm")
        
        let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                ILOG("Migrating to version 2.")
            }
            ILOG("Migration complete.")
        }
        
        let config = Realm.Configuration(fileURL: realmURL, inMemoryIdentifier: nil, syncConfiguration: nil, encryptionKey: nil, readOnly: false, schemaVersion: 2, migrationBlock: migrationBlock, deleteRealmIfMigrationNeeded: false, shouldCompactOnLaunch: nil, objectTypes: nil)
        return config
    }()
}

public final class RomDatabase : NSObject {
    
    // Private shared instance that propery initializes
    private static var _sharedInstance : RomDatabase =  {
        RealmConfiguration.setDefaultRealmConfig()
        return RomDatabase()
    }()

    // Public shared instance that makes sure threads are handeled right
    // TODO: Since if a function calls a bunch of RomDatabase.sharedInstance calls,
    // this helper might do more damage than just putting a fatalError() around isMainThread
    // and simply fixing any threaded callst to call temporaryDatabaseContext
    // Or maybe there should be no public sharedInstance and instead only a
    // databaseContext object that must be used for all calls. It would be another class
    // and RomDatabase would just exist to provide context instances and init the initial database - jm
    @objc
    public static var sharedInstance : RomDatabase {
        // Make sure real shared is inited first
        let shared = RomDatabase._sharedInstance
        
        if Thread.isMainThread {
            return shared
        } else {
            return RomDatabase.temporaryDatabaseContext()
        }
    }
    
    // For multi-threading
    @objc
    public static func temporaryDatabaseContext() -> RomDatabase {
        return RomDatabase()
    }
    
    fileprivate var realm : Realm
    
    override init() {
        do {
            self.realm = try Realm()
        } catch {
            fatalError("\(error.localizedDescription)")
        }

        super.init()
    }
}

// MARK: - Queries
public extension RomDatabase {
    // Generics
    public func all<T:Object>(_ type : T.Type) -> Results<T> {
        return realm.objects(type)
    }
    
    
    // Testing a Swift hack to make Swift 4 keypaths work with KVC keypaths
/*
    public func all<T:Object>(sorthedByKeyPath keyPath : KeyPath<T, AnyKeyPath>, ascending: Bool = true) -> Results<T> {
        return realm.objects(T.self).sorted(byKeyPath: keyPath._kvcKeyPathString!, ascending: ascending)
    }
    
    public func all<T:Object>(where keyPath: KeyPath<T, AnyKeyPath>, value : String) -> Results<T> {
        return T.objects(in: self.realm, with: NSPredicate(format: "\(keyPath._kvcKeyPathString) == %@", value))
    }
     
     public func allGames(sortedByKeyPath keyPath: KeyPath<PVGame, AnyKeyPath>, ascending: Bool = true) -> Results<PVGame> {
        return all(sorthedByKeyPath: keyPath, ascending: ascending)
     }

*/
    
    public func all<T:Object>(_ type : T.Type, sorthedByKeyPath keyPath : String, ascending: Bool = true) -> Results<T> {
        return realm.objects(T.self).sorted(byKeyPath: keyPath, ascending: ascending)
    }
    
    public func all<T:Object>(_ type : T.Type, where keyPath: String, value : String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", value))
    }
    
    public func all<T:Object>(_ type : T.Type, filter: NSPredicate) -> Results<T> {
        return realm.objects(T.self).filter(filter)
    }
    
    // HELPERS -- TODO: Get rid once we're all swift
    public var allGames : Results<PVGame> {
        return self.all(PVGame.self)
    }
    
    public func allGames(sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<PVGame> {
        return all(PVGame.self, sorthedByKeyPath: keyPath, ascending: ascending)
    }
}

// MARK: - Update
public extension RomDatabase {
    @objc
    public func writeTransaction(_ block: () -> Void) throws {
        try realm.write {
            block()
        }
    }
    
    @objc
    public func add(object: Object, update: Bool = true) throws {
        try realm.write {
            realm.add(object, update: update)
        }
    }
    
    public func add<T:Object>(objects: [T], update: Bool = true) throws {
        try realm.write {
            realm.add(objects, update: update)
        }
    }
    
    @objc
    public func deleteAll() throws {
        try realm.write {
            realm.deleteAll()
        }
    }
    
    public func deleteAll<T:Object>(_ type : T.Type) throws {
        try realm.write {
            realm.delete(realm.objects(type))
        }
    }
    
    @objc
    public func delete(object: Object) throws {
        try realm.write {
            realm.delete(object)
        }
    }
}

public extension RomDatabase {
    @objc
    public func refresh() {
        realm.refresh()
    }
}
