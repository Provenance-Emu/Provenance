//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import UIKit

public typealias SQLiteRomDB = SQLiteRomDatabase
public final class SQLiteRomDatabase {
    public private(set) static var databaseInitilized = false

    public class func initDefaultDatabase() throws {
        if !databaseInitilized {
            // Init
            databaseInitilized = true
        }
    }

    private static func createInitialLocalLibrary() {
        // This is all pretty much place holder as I scope out the idea of
        // local and remote libraries
        let newLibrary = PVSQLiteLibrary()
        newLibrary.bonjourName = ""
        newLibrary.domainname = "localhost"
        newLibrary.name = "Default Library"
        newLibrary.ipaddress = "127.0.0.1"
        if let existingGames = _sharedInstance?.realm.objects(PVGame.self).filter("libraries.@count == 0") {
            newLibrary.games.append(objectsIn: existingGames)
        }
        try! _sharedInstance?.add(newLibrary)
        _sharedInstance.libraryRef = ThreadSafeReference(to: newLibrary)
    }

    // Primary local library

    private var libraryRef: ThreadSafeReference<PVLibrary>!
    public var library: PVLibrary {
        let realm = try! Realm()
        return realm.resolve(libraryRef)!
    }

    //	public static var localLibraries : Results<PVLibrary> {
    //		return sharedInstance.realm.objects(PVLibrary.self).filter { $0.isLocal }
    //	}
//
    //	public static var remoteLibraries : Results<PVLibrary> {
    //		return sharedInstance.realm.objects(PVLibrary.self).filter { !$0.isLocal }
    //	}

    // Private shared instance that propery initializes
    private static var _sharedInstance: RomDatabase!

    // Public shared instance that makes sure threads are handeled right
    // TODO: Since if a function calls a bunch of RomDatabase.sharedInstance calls,
    // this helper might do more damage than just putting a fatalError() around isMainThread
    // and simply fixing any threaded callst to call temporaryDatabaseContext
    // Or maybe there should be no public sharedInstance and instead only a
    // databaseContext object that must be used for all calls. It would be another class
    // and RomDatabase would just exist to provide context instances and init the initial database - jm
    public static var sharedInstance: RomDatabase {
        // Make sure real shared is inited first
        let shared = RomDatabase._sharedInstance!

        if Thread.isMainThread {
            return shared
        } else {
            if let realm = Thread.current.realm {
                return realm
            } else {
                let realm = try! RomDatabase.temporaryDatabaseContext()
                Thread.current.realm = realm
                return realm
            }
        }
    }

    // For multi-threading
    fileprivate static func temporaryDatabaseContext() throws -> RomDatabase {
        return try RomDatabase()
    }

    public private(set) var realm: Realm

    private init() throws {
        realm = try Realm()
    }
}

// MARK: - Queries

public extension RomDatabase {
    // Generics
    func all<T: Object>(_ type: T.Type) -> Results<T> {
        return realm.objects(type)
    }

    // Testing a Swift hack to make Swift 4 keypaths work with KVC keypaths
    /*
     public func all<T:Object>(sortedByKeyPath keyPath : KeyPath<T, AnyKeyPath>, ascending: Bool = true) -> Results<T> {
     return realm.objects(T.self).sorted(byKeyPath: keyPath._kvcKeyPathString!, ascending: ascending)
     }

     public func all<T:Object>(where keyPath: KeyPath<T, AnyKeyPath>, value : String) -> Results<T> {
     return T.objects(in: self.realm, with: NSPredicate(format: "\(keyPath._kvcKeyPathString) == %@", value))
     }

     public func allGames(sortedByKeyPath keyPath: KeyPath<PVGame, AnyKeyPath>, ascending: Bool = true) -> Results<PVGame> {
     return all(sortedByKeyPath: keyPath, ascending: ascending)
     }

     */

    func all<T: Object>(_: T.Type, sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<T> {
        return realm.objects(T.self).sorted(byKeyPath: keyPath, ascending: ascending)
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, contains value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) CONTAINS[cd] %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, beginsWith value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) BEGINSWITH[cd] %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: Bool) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", NSNumber(value: value)))
    }

    func all<T: Object, KeyType>(_: T.Type, where keyPath: String, value: KeyType) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", [value]))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: Int) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %i", value))
    }

    func all<T: Object>(_: T.Type, filter: NSPredicate) -> Results<T> {
        return realm.objects(T.self).filter(filter)
    }

    func object<T: Object, KeyType>(ofType _: T.Type, wherePrimaryKeyEquals value: KeyType) -> T? {
        return realm.object(ofType: T.self, forPrimaryKey: value)
    }

    // HELPERS -- TODO: Get rid once we're all swift
    var allGames: Results<PVGame> {
        return all(PVGame.self)
    }

    func allGames(sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<PVGame> {
        return all(PVGame.self, sortedByKeyPath: keyPath, ascending: ascending)
    }

    func allGamesSortedBySystemThenTitle() -> Results<PVGame> {
        return realm.objects(PVGame.self).sorted(byKeyPath: "systemIdentifier").sorted(byKeyPath: "title")
    }
}

public enum RomDeletionError: Error {
    case relatedFiledDeletionError
}

// MARK: - Update

public extension RomDatabase {
    @objc
    func writeTransaction(_ block: () -> Void) throws {
        if realm.isInWriteTransaction {
            block()
        } else {
            try realm.write {
                block()
            }
        }
    }

    @objc
    func add(_ object: Object, update: Bool = false) throws {
        try writeTransaction {
            realm.add(object, update: update ? .all : .error)
        }
    }

    func add<T: Object>(objects: [T], update: Bool = false) throws {
        try writeTransaction {
            realm.add(objects, update: update ? .all : .error)
        }
    }

    func deleteAll() throws {
        try writeTransaction {
            realm.deleteAll()
        }
    }

    @objc
    func delete(_ object: Object) throws {
        try writeTransaction {
            realm.delete(object)
        }
    }

    func renameGame(_ game: PVGame, toTitle title: String) {
        if !title.isEmpty {
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    game.title = title
                }

                if game.releaseID == nil || game.releaseID!.isEmpty {
                    ILOG("Game isn't already matched, going to try to re-match after a rename")
                    GameImporter.shared.lookupInfo(for: game, overwrite: false)
                }
            } catch {
                ELOG("Failed to rename game \(game.title)\n\(error.localizedDescription)")
            }
        }
    }

    func delete(game: PVGame) throws {
        let romURL = PVEmulatorConfiguration.path(forGame: game)

        if !game.customArtworkURL.isEmpty {
            do {
                try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            } catch {
                ELOG("Failed to delete image " + game.customArtworkURL)
                // Don't throw, not a big deal
            }
        }

        let savesPath = PVEmulatorConfiguration.saveStatePath(forGame: game)
        if FileManager.default.fileExists(atPath: savesPath.path) {
            do {
                try FileManager.default.removeItem(at: savesPath)
            } catch {
                ELOG("Unable to delete save states at path: " + savesPath.path + "because: " + error.localizedDescription)
            }
        }

        let batteryPath = PVEmulatorConfiguration.batterySavesPath(forGame: game)
        if FileManager.default.fileExists(atPath: batteryPath.path) {
            do {
                try FileManager.default.removeItem(at: batteryPath)
            } catch {
                ELOG("Unable to delete battery states at path: \(batteryPath.path) because: \(error.localizedDescription)")
            }
        }

        if game.file.online {
            do {
                try FileManager.default.removeItem(at: romURL)
            } catch {
                ELOG("Unable to delete rom at path: \(romURL.path) because: \(error.localizedDescription)")
                throw error
            }
        }

        // Delete from Spotlight search
        #if os(iOS)
            deleteFromSpotlight(game: game)
        #endif

        do {
            game.saveStates.forEach { try? $0.delete() }
            game.recentPlays.forEach { try? $0.delete() }
            game.screenShots.forEach { try? $0.delete() }

            try deleteRelatedFilesGame(game)
            try game.delete()
        } catch {
            // Delete the DB entry anyway if any of the above files couldn't be removed
            try game.delete()
            throw error
        }
    }

    func deleteRelatedFilesGame(_ game: PVGame) throws {
        guard let system = game.system else {
            ELOG("Game \(game.title) belongs to an unknown system \(game.systemIdentifier)")
            throw RomDeletionError.relatedFiledDeletionError
        }

        try game.relatedFiles.forEach {
            try FileManager.default.removeItem(at: $0.url)
        }

        let romDirectory = system.romsDirectory
        let relatedFileName: String = game.url.deletingPathExtension().lastPathComponent

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: romDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        } catch {
            ELOG("scanning \(romDirectory) \(error.localizedDescription)")
            return
        }

        let matchingFiles = contents.filter {
            let filename = $0.deletingPathExtension().lastPathComponent
            return filename.contains(relatedFileName)
        }

        try matchingFiles.forEach {
            let file = romDirectory.appendingPathComponent($0.lastPathComponent, isDirectory: false)
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                ELOG("Failed to remove item \(file.path).\n \(error.localizedDescription)")
                throw error
            }
        }
    }
}

// MARK: - Spotlight

#if os(iOS)
    import CoreSpotlight

    extension RomDatabase {
        private func deleteFromSpotlight(game: PVGame) {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [game.spotlightUniqueIdentifier], completionHandler: { error in
                if let error = error {
                    print("Error deleting game spotlight item: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            })
        }

        private func deleteAllGamesFromSpotlight() {
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                if let error = error {
                    print("Error deleting all games spotlight index: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            }
        }
    }
#endif

public extension RomDatabase {
    @objc
    func refresh() {
        realm.refresh()
    }
}
