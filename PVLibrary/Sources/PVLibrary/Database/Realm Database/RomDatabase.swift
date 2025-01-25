//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
#if canImport(UIKit)
import UIKit
#endif
import PVLookup
import PVHashing
import PVRealm
import AsyncAlgorithms
import PVSystems
import PVMediaCache

let schemaVersion: UInt64 = 14

public enum RomDeletionError: Error {
    case relatedFiledDeletionError
    case fileManagerDeletionError(Error)
}

public final class RealmConfiguration {
    public class var supportsAppGroups: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return !PVAppGroupId.isEmpty && RealmConfiguration.appGroupContainer != nil
#endif
    }

    public class var appGroupContainer: URL? {
#if targetEnvironment(macCatalyst)
        return nil
#else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
#endif
    }

    public class var appGroupPath: URL? {
        guard let appGroupContainer = RealmConfiguration.appGroupContainer else {
            ILOG("appGroupContainer is Nil")
            return nil
        }

        ILOG("appGroupContainer => (\(appGroupContainer.absoluteString))")

#if os(tvOS)
        let appGroupPath = appGroupContainer.appendingPathComponent("Library/Caches/")
#else
        let appGroupPath = appGroupContainer
#endif
        return appGroupPath
    }

    public class func setDefaultRealmConfig() {
        let config = RealmConfiguration.realmConfig
        Realm.Configuration.defaultConfiguration = config
    }

    private static var realmConfig: Realm.Configuration = {
        let realmFilename = "default.realm"
        let nonGroupPath = URL.documentsPath.appendingPathComponent(realmFilename, isDirectory: false)

        var realmURL: URL = nonGroupPath
        if RealmConfiguration.supportsAppGroups, let appGroupPath = RealmConfiguration.appGroupPath {
            ILOG("AppGroups: Supported")
            realmURL = appGroupPath.appendingPathComponent(realmFilename, isDirectory: false)

            let fm = FileManager.default
            if fm.fileExists(atPath: nonGroupPath.path) {
                do {
                    ILOG("Found realm database at non-group path location. Will attempt to move to group path location")
                    if fm.fileExists(atPath: realmURL.path) {
                        try fm.removeItem(at: realmURL)
                    }
                    try fm.moveItem(at: nonGroupPath, to: realmURL)
                    ILOG("Moved old database to group path location.")
                } catch {
                    ELOG("Failed to move old database to new group path: \(error.localizedDescription)")
                }
            }
        } else {
            ILOG("AppGroups: Not Supported")
        }

        let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                ILOG("Migrating to version 2. Adding MD5s")
                NotificationCenter.default.post(name: NSNotification.Name.DatabaseMigrationStarted, object: nil)

                var counter = 0
                var deletions = 0
                migration.enumerateObjects(ofType: PVGame.className()) { oldObject, newObject in
                    let romPath = oldObject!["romPath"] as! String
                    let systemID = oldObject!["systemIdentifier"] as! String
                    let system = SystemIdentifier(rawValue: systemID)!

                    var offset: UInt = 0
                    if system == .SNES {
                        offset = 16
                    }

                    let fullPath = URL.documentsPath.appendingPathComponent(romPath, isDirectory: false)
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: fullPath.path) {
                        ELOG("Cannot find file at path: \(fullPath). Deleting entry")
                        if let oldObject = oldObject {
                            migration.delete(oldObject)
                            deletions += 1
                        }
                        return
                    }

                    if let md5 = FileManager.default.md5ForFile(atPath: fullPath.path, fromOffset: UInt(offset)), !md5.isEmpty {
                        newObject!["md5Hash"] = md5
                        counter += 1
                    } else {
                        ELOG("Couldn't get md5 for \(fullPath.path). Removing entry")
                        if let oldObject = oldObject {
                            migration.delete(oldObject)
                            deletions += 1
                        }
                    }

                    newObject!["importDate"] = Date()
                }

                NotificationCenter.default.post(name: NSNotification.Name.DatabaseMigrationFinished, object: nil)
                ILOG("Migration complete of \(counter) roms. Removed \(deletions) bad entries.")
            }
            if oldSchemaVersion < 10 {
                migration.enumerateObjects(ofType: PVCore.className()) { oldObject, newObject in
                    newObject!["disabled"] = false
                }
            }
            if oldSchemaVersion < 11 {
                migration.enumerateObjects(ofType: PVSystem.className()) { oldObject, newObject in
                    newObject!["supported"] = true
                }
            }
            if oldSchemaVersion < 12 {
                migration.enumerateObjects(ofType: PVRecentGame.className()) { oldObject, newObject in
                    newObject!["id"] = NSUUID().uuidString
                }
            }
            if oldSchemaVersion < 13 {
                migration.enumerateObjects(ofType: PVCore.className()) { oldObject, newObject in
                    newObject!["appStoreDisabled"] = false
                }
                migration.enumerateObjects(ofType: PVSystem.className()) { oldObject, newObject in
                    newObject!["appStoreDisabled"] = false
                }
            }
            if oldSchemaVersion < 14 {
                migration.enumerateObjects(ofType: PVSaveState.className()) { oldObject, newObject in
                    newObject!["isPinned"] = false
                    newObject!["isFavorite"] = false
                }
            }
        }

#if DEBUG
        let deleteIfMigrationNeeded = true
#else
        let deleteIfMigrationNeeded = false
#endif
        let config = Realm.Configuration(
            fileURL: realmURL,
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: nil,
            readOnly: false,
            schemaVersion: schemaVersion,
            migrationBlock: migrationBlock,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: { totalBytes, usedBytes in
                // totalBytes refers to the size of the file on disk in bytes (data + free space)
                // usedBytes refers to the number of bytes used by data in the file

                // Compact if the file is over 20MB in size and less than 60% 'used'
                let twentyMB = 20 * 1024 * 1024
                return (totalBytes > twentyMB) && (Double(usedBytes) / Double(totalBytes)) < 0.6
            },
            objectTypes: [
                PVBIOS.self,
                PVCheats.self,
                PVCore.self,
                PVGame.self,
                PVLibrary.self,
                PVRecentGame.self,
                PVSaveState.self,
                PVSystem.self,
                PVUser.self,
                PVFile.self,
                PVImageFile.self
            ]
        )

        return config
    }()
}

internal final class WeakWrapper: NSObject {
    static var associatedKey = "WeakWrapper"
    weak var weakObject: RomDatabase?

    init(_ weakObject: RomDatabase?) {
        self.weakObject = weakObject
    }
}

import ObjectiveC
public extension Thread {
    var realm: RomDatabase? {
        get {
            let weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, WeakWrapper.associatedKey) as? WeakWrapper
            return weakWrapper?.weakObject
        }
        set {
            var weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, WeakWrapper.associatedKey) as? WeakWrapper
            if weakWrapper == nil {
                weakWrapper = WeakWrapper(newValue)
                objc_setAssociatedObject(self, WeakWrapper.associatedKey, weakWrapper, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                weakWrapper!.weakObject = newValue
            }
        }
    }
}

public typealias RomDB = RomDatabase


public final class RomDatabase {

    public private(set) static var databaseInitialized = false

    static var _gamesCache: [String: PVGame]?
    public static var gamesCache: [String: PVGame] {
        guard let _gamesCache = _gamesCache else {
            reloadGamesCache(force: true)
            return gamesCache
        }
        return _gamesCache
    }

    static var _systemCache: [String: PVSystem]?
    public static var systemCache: [String: PVSystem] {
        guard let _systemCache = _systemCache else {
            reloadSystemsCache(force: true)
            return systemCache
        }
        return _systemCache
    }

    static var _coreCache: [String: PVCore]?
    public static var coreCache: [String: PVCore] {
        guard let _coreCache = _coreCache else {
            reloadCoresCache(force: true)
            return coreCache
        }
        return _coreCache
    }

    static var _biosCache: [String: [String]]?
    public static var biosCache: [String: [String]] {
        guard let _biosCache = _biosCache else {
            reloadBIOSCache()
            return biosCache
        }
        return _biosCache
    }

    static var _fileSystemROMCache: [URL: PVSystem]?
    public static var fileSystemROMCache: [URL: PVSystem] {
        guard let _fileSystemROMCache = _fileSystemROMCache else {
            reloadFileSystemROMCache()
            return fileSystemROMCache
        }
        return _fileSystemROMCache
    }

    static var _artMD5DBCache: [String: [String: AnyObject]]?
    public static var artMD5DBCache: [String: [String: AnyObject]] {
        guard let _artMD5DBCache = _artMD5DBCache else {
            reloadArtDBCache()
            return artMD5DBCache
        }
        return _artMD5DBCache
    }

    static var _artFileNameToMD5Cache: [String: String]?
    public static var artFileNameToMD5Cache: [String: String] {
        guard let _artFileNameToMD5Cache = _artFileNameToMD5Cache else {
            reloadArtDBCache()
            return artFileNameToMD5Cache
        }
        return _artFileNameToMD5Cache
    }

    @MainActor
    public class func initDefaultDatabase() async throws {
        if !databaseInitialized {
            ILOG("Setting default Realm configuration")
            RealmConfiguration.setDefaultRealmConfig()

            ILOG("Creating RomDatabase instance")
            _sharedInstance = try RomDatabase()

            ILOG("Checking for existing local libraries")
            let existingLocalLibraries = _sharedInstance.realm.objects(PVLibrary.self).filter("isLocal == YES")

            if !existingLocalLibraries.isEmpty, let first = existingLocalLibraries.first {
                ILOG("Existing PVLibrary found")
                _sharedInstance.libraryRef = ThreadSafeReference(to: first)
            } else {
                ILOG("No local library found, creating initial local library")
                try await createInitialLocalLibrary()
            }

            ILOG("Database initialization completed")
            databaseInitialized = true
            NotificationCenter.default.post(name: .RomDatabaseInitialized, object: nil, userInfo: nil)
            
        } else {
            ILOG("Database already initialized")
        }
    }

    @MainActor
    private static func createInitialLocalLibrary() async throws {
        ILOG("Creating initial local library")
        let newLibrary = PVLibrary()
        newLibrary.bonjourName = ""
        newLibrary.domainname = "localhost"
        newLibrary.name = "Default Library"
        newLibrary.ipaddress = "127.0.0.1"

        ILOG("Checking for existing games")
        if let existingGames = _sharedInstance?.realm.objects(PVGame.self).filter("libraries.@count == 0") {
            newLibrary.games.append(objectsIn: existingGames)
        }

        ILOG("Adding new library to database")
        do {
            try _sharedInstance?.add(newLibrary)
            _sharedInstance.libraryRef = ThreadSafeReference(to: newLibrary)
            ILOG("Initial local library created successfully")
        } catch {
            ELOG("Error creating initial local library: \(error.localizedDescription)")
            throw error
        }
    }

    // Primary local library

    private var libraryRef: ThreadSafeReference<PVLibrary>!
    public var library: PVLibrary {
        let realm = try! Realm()
        return realm.resolve(libraryRef)!
    }

    //    public static var localLibraries : Results<PVLibrary> {
    //        return sharedInstance.realm.objects(PVLibrary.self).filter { $0.isLocal }
    //    }
    //
    //    public static var remoteLibraries : Results<PVLibrary> {
    //        return sharedInstance.realm.objects(PVLibrary.self).filter { !$0.isLocal }
    //    }

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
        guard let shared = RomDatabase._sharedInstance else {
            return try! RomDatabase()
        }

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
    
    // MARK: Save States
    
    func allSaveStates() -> Results<PVSaveState> {
        return all(PVSaveState.self)
    }
    
    func allSaveStates(forGameWithID gameID: String) -> Results<PVSaveState> {
        let game = realm.object(ofType: PVGame.self, forPrimaryKey: gameID)
        return realm.objects(PVSaveState.self).filter("game == %@", game as Any)
    }
    
    func savetate(forID saveStateID: String) -> PVSaveState? {
        if let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateID) {
            return saveState
        } else {
            return nil
        }
    }
}

public extension Object {
    static func all() -> Results<PersistedType> {
        try! Realm().objects(Self.PersistedType)
    }
    
    static func forPrimaryKey(_ primaryKey: String) -> PersistedType? {
        try! Realm().object(ofType: Self.PersistedType.self, forPrimaryKey: primaryKey)
    }
}

// MARK: - Update

public extension RomDatabase {
    @objc
    func writeTransaction(_ block: () -> Void) throws {
        try autoreleasepool {
            let realm = Thread.isMainThread ? self.realm : try Realm()
            if realm.isInWriteTransaction {
                block()
            } else {
                try realm.write {
                    block()
                }
            }
        }
    }

    @objc
    func asyncWriteTransaction(_ block: @escaping () -> Void) {
        DispatchQueue.main.async {
            let realm = self.realm
            if realm.isInWriteTransaction {
                block()
            } else {
                realm.writeAsync {
                    autoreleasepool {
                        block()
                    }
                }
            }
        }
    }

    @objc
    func add(_ object: Object, update: Bool = false) throws {
        try writeTransaction {
            realm.add(object, update: update ? .all : .error)
        }
    }

    @objc
    func addAsync(_ object: Object, update: Bool = false) async throws {
        ILOG("Adding object to database")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let realm = self.realm
                    try realm.write {
                        realm.add(object, update: update ? .all : .error)
                    }
                    ILOG("Object added successfully")
                    continuation.resume()
                } catch {
                    ELOG("Error adding object to database: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func add<T: Object>(objects: [T], update: Bool = false) throws {
        try writeTransaction {
            realm.add(objects, update: update ? .all : .error)
        }
    }
    func deleteAll() throws {
        Realm.Configuration.defaultConfiguration.deleteRealmIfMigrationNeeded = true
        let realm = Thread.isMainThread ? self.realm : try Realm()
        try realm.write {
            realm.deleteAll()
        }
    }
    func deleteAllData() throws {
        WLOG("!!!deleteAllData Called!!!")
        let realm = try! Realm()
        let games = realm.objects(PVGame.self)
        let system = realm.objects(PVSystem.self)
        let core = realm.objects(PVCore.self)
        let saves = realm.objects(PVSaveState.self)
        let recent = realm.objects(PVRecentGame.self)
        let user = realm.objects(PVUser.self)
        try! realm.write {
            realm.delete(games)
            realm.delete(system)
            realm.delete(core)
            realm.delete(saves)
            realm.delete(recent)
            realm.delete(user)
            realm.deleteAll()
        }
    }

    func deleteAllGames() throws {
        let realm = try! Realm()
        let allUploadingObjects = realm.objects(PVGame.self)

        try! realm.write {
            realm.delete(allUploadingObjects)
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
                    game.realm?.refresh()
                    game.title = title
                        if game.releaseID == nil || game.releaseID!.isEmpty {
                            ILOG("Game isn't already matched, going to try to re-match after a rename")
                            //TODO: figure out when this happens and fix
                            //GameImporter.shared.lookupInfo(for: game, overwrite: false)
                        }
                }
            } catch {
                ELOG("Failed to rename game \(game.title)\n\(error.localizedDescription)")
            }
        }
    }
    func hideGame(_ game: PVGame) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.realm?.refresh()
                game.genres = "hidden"
            }
        } catch {
            NSLog("Failed to hide game \(game.title)\n\(error.localizedDescription)")
        }
    }
    
    func delete(bios: PVBIOS) throws {
        guard let biosURL = bios.file?.url else {
            ELOG("No path for BIOS")
            throw RomDeletionError.relatedFiledDeletionError
        }
        if FileManager.default.fileExists(atPath: biosURL.path) {
            do {
                try FileManager.default.removeItem(at: biosURL)
                ILOG("Deleted BIOS \(bios.expectedFilename)\n\(biosURL.path)")
                // Remove the PVFile from the PVBios
                let realm = try Realm()
                let bios = bios.warmUp()
                try realm.write {
                    bios.file = nil
                }
            } catch {
                WLOG("Failed to delete BIOS \(bios.expectedFilename)\n\(error.localizedDescription)")
            }
        }
    }
    
    func delete(game: PVGame, deleteArtwork: Bool = false, deleteSaves: Bool = false) throws {
        let romURL = PVEmulatorConfiguration.path(forGame: game)
        if deleteArtwork, !game.customArtworkURL.isEmpty {
            do {
                try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            } catch {
                WLOG("Failed to delete image " + game.customArtworkURL)
                // Don't throw, not a big deal
            }
        }
        if deleteSaves {
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
        }
        if FileManager.default.fileExists(atPath: romURL.path) {
            do {
                try FileManager.default.removeItem(at: romURL)
            } catch {
                ELOG("Unable to delete rom at path: \(romURL.path) because: \(error.localizedDescription)")
                throw RomDeletionError.fileManagerDeletionError(error)
            }
        } else {
            ELOG("No rom found at path: \(romURL.path)")
        }
        // Delete from Spotlight search
#if os(iOS)
        deleteFromSpotlight(game: game)
#endif
        do {
            deleteRelatedFilesGame(game)
            game.saveStates.forEach { try? $0.delete() }
            game.cheats.forEach { try? $0.delete() }
            game.recentPlays.forEach { try? $0.delete() }
            game.screenShots.forEach { try? $0.delete() }
            try game.delete()
        } catch {
            // Delete the DB entry anyway if any of the above files couldn't be removed
            do { try game.delete() } catch {
                ELOG("\(error.localizedDescription)")
            }
            ELOG("\(error.localizedDescription)")
        }
    }

    // Deletes a save state and its associated files
    /// Deletes a save state and its associated files
    func delete(saveState: PVSaveState) throws {
        // Get the actual save state file path from the PVFile
        let actualSavePath = saveState.file.url
        let imageURL = saveState.image?.url
        
        // Create a thread-safe reference to the save state
        let saveStateRef = ThreadSafeReference(to: saveState)
        
        // First delete the database entry
        do {
            try realm.write {
                // Resolve the reference in this Realm instance
                if let saveStateToDelete = realm.resolve(saveStateRef) {
                    realm.delete(saveStateToDelete)
                } else {
                    ELOG("Failed to resolve save state reference in current Realm")
                    throw RomDeletionError.relatedFiledDeletionError
                }
            }
        } catch {
            ELOG("Failed to delete save state from database: \(error.localizedDescription)")
            throw error
        }
        
        // After successful database deletion, delete the files
        if FileManager.default.fileExists(atPath: actualSavePath.path) {
            do {
                try FileManager.default.removeItem(at: actualSavePath)
            } catch {
                ELOG("Unable to delete save state at path: \(actualSavePath.path) because: \(error.localizedDescription)")
                throw RomDeletionError.fileManagerDeletionError(error)
            }
        }
        
        // Delete the screenshot if it exists
        if let imagePath = imageURL,
        FileManager.default.fileExists(atPath: imagePath.path) {
            do {
                try FileManager.default.removeItem(at: imagePath)
            } catch {
                ELOG("Unable to delete screenshot at path: \(imagePath.path) because: \(error.localizedDescription)")
                throw RomDeletionError.fileManagerDeletionError(error)
            }
        }
    }

    func deleteRelatedFilesGame(_ game: PVGame) {
//        guard let system = game.system else {
//            ELOG("Game \(game.title) belongs to an unknown system \(game.systemIdentifier)")
//            return
//        }
        game.relatedFiles.forEach {
            do {
                let file = PVEmulatorConfiguration.path(forGame: game, url: $0.url)
                if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                NSLog(error.localizedDescription)
            }
        }
    }
}

public extension RomDatabase {
    @objc
    static func refresh() {
        let realm = try! Realm()
        realm.refresh()

//        Task { @MainActor in
//        }
    }
}
