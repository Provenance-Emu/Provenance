//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit

public extension Notification.Name {
    static let DatabaseMigrationStarted  = Notification.Name("DatabaseMigrarionStarted")
    static let DatabaseMigrationFinished = Notification.Name("DatabaseMigrarionFinished")
}

public class RealmConfiguration {
    class public var supportsAppGroups: Bool {
        return !PVAppGroupId.isEmpty && RealmConfiguration.appGroupContainer != nil
    }

    class public var appGroupContainer: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
    }

    class public var appGroupPath: String? {
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

    private static var realmConfig: Realm.Configuration = {
        #if os(tvOS)
            var path: String? = nil
            if RealmConfiguration.supportsAppGroups {
                path = RealmConfiguration.appGroupPath
            } else {
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

                    let fullPath = PVEmulatorConfiguration.documentsPath.appendingPathComponent(romPath, isDirectory: false)
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: fullPath.path) {
                        ELOG("Cannot find file at path: \(fullPath). Deleting entry")
                        if let oldObject = oldObject {
                            migration.delete(oldObject)
                            deletions += 1
                        }
                        return
                    }

                    if let md5 = FileManager.default.md5ForFile(atPath: fullPath.path, fromOffset: offset), !md5.isEmpty {
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
        }

        #if DEBUG
            let deleteIfMigrationNeeded = true
        #else
            let deleteIfMigrationNeeded = false
        #endif
        let config = Realm.Configuration(fileURL: realmURL, inMemoryIdentifier: nil, syncConfiguration: nil, encryptionKey: nil, readOnly: false, schemaVersion: 3, migrationBlock: migrationBlock, deleteRealmIfMigrationNeeded: false, shouldCompactOnLaunch: nil, objectTypes: nil)
        return config
    }()
}

internal class WeakWrapper: NSObject {
    static var associatedKey = "WeakWrapper"
    weak var weakObject: RomDatabase?

    init(_ weakObject: RomDatabase?) {
        self.weakObject = weakObject
    }
}
import ObjectiveC
extension Thread {
    var realm: RomDatabase? {
        get {
            let weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, &WeakWrapper.associatedKey) as? WeakWrapper
            return weakWrapper?.weakObject
        }
        set {
            var weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, &WeakWrapper.associatedKey) as? WeakWrapper
            if weakWrapper == nil {
                weakWrapper = WeakWrapper(newValue)
                objc_setAssociatedObject(self, &WeakWrapper.associatedKey, weakWrapper, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                weakWrapper!.weakObject = newValue
            }
        }
    }
}

public typealias RomDB = RomDatabase
public final class RomDatabase {

	static var databaseInitilized = false

	public class func initDefaultDatabase() throws {
		if !databaseInitilized {
			RealmConfiguration.setDefaultRealmConfig()
			try _sharedInstance = RomDatabase()
			databaseInitilized = true

			let existingLocalLibraries = _sharedInstance.realm.objects(PVLibrary.self).filter("isLocal == YES")

			if !existingLocalLibraries.isEmpty, let first = existingLocalLibraries.first {
				VLOG("Existing PVLibrary(s) found.")
				_sharedInstance.libraryRef = ThreadSafeReference(to: first)
			} else {
				VLOG("No local library, need to create")
				createInitialLocalLibrary()
			}
		}
	}

	private static func createInitialLocalLibrary() {
		// This is all pretty much place holder as I scope out the idea of
		// local and remote libraries
		let newLibrary = PVLibrary()
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

	private var libraryRef : ThreadSafeReference<PVLibrary>!
	public var library : PVLibrary {
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

    private(set) public var realm: Realm

    private init() throws {
		self.realm = try Realm()
    }
}

// MARK: - Queries
public extension RomDatabase {
    // Generics
    public func all<T: Object>(_ type: T.Type) -> Results<T> {
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

    public func all<T: Object>(_ type: T.Type, sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<T> {
        return realm.objects(T.self).sorted(byKeyPath: keyPath, ascending: ascending)
    }

    public func all<T: Object>(_ type: T.Type, where keyPath: String, value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", value))
    }

	public func all<T: Object>(_ type: T.Type, where keyPath: String, contains value: String) -> Results<T> {
		return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) CONTAINS[cd] %@", value))
	}

	public func all<T: Object>(_ type: T.Type, where keyPath: String, beginsWith value: String) -> Results<T> {
		return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) BEGINSWITH[cd] %@", value))
	}

    public func all<T: Object>(_ type: T.Type, where keyPath: String, value: Bool) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", NSNumber(value: value)))
    }

    public func all<T: Object, KeyType>(_ type: T.Type, where keyPath: String, value: KeyType) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", [value]))
    }

	public func all<T: Object>(_ type: T.Type, where keyPath: String, value: Int) -> Results<T> {
		return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %i", value))
	}

    public func all<T: Object>(_ type: T.Type, filter: NSPredicate) -> Results<T> {
        return realm.objects(T.self).filter(filter)
    }

    public func object<T: Object, KeyType>(ofType type: T.Type, wherePrimaryKeyEquals value: KeyType) -> T? {
        return realm.object(ofType: T.self, forPrimaryKey: value)
    }

    // HELPERS -- TODO: Get rid once we're all swift
    public var allGames: Results<PVGame> {
        return self.all(PVGame.self)
    }

    public func allGames(sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<PVGame> {
        return all(PVGame.self, sortedByKeyPath: keyPath, ascending: ascending)
    }

    public func allGamesSortedBySystemThenTitle() -> Results<PVGame> {
        return realm.objects(PVGame.self).sorted(byKeyPath: "systemIdentifier").sorted(byKeyPath: "title")
    }
}

public enum RomDeletionError : Error {
	case relatedFiledDeletionError
}

// MARK: - Update
public extension RomDatabase {
    @objc
    public func writeTransaction(_ block: () -> Void) throws {
		if realm.isInWriteTransaction {
			block()
		} else {
			try realm.write {
				block()
			}
		}
    }

    @objc
    public func add(_ object: Object, update: Bool = false) throws {
		try writeTransaction {
            realm.add(object, update: update)
        }
    }

    public func add<T: Object>(objects: [T], update: Bool = false) throws {
		try writeTransaction {
            realm.add(objects, update: update)
        }
    }

    @objc
    public func deleteAll() throws {
		try writeTransaction {
            realm.deleteAll()
        }
    }

    public func deleteAll<T: Object>(_ type: T.Type) throws {
		try writeTransaction {
			realm.delete(realm.objects(type))
		}
    }

    @objc
    public func delete(_ object: Object) throws {
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
					PVGameImporter.shared.lookupInfo(for: game, overwrite: false)
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

		if !game.file.missing {
			do {
				try FileManager.default.removeItem(at: romURL)
			} catch {
				ELOG("Unable to delete rom at path: \(romURL.path) because: \(error.localizedDescription)")
				throw error
			}
		}

		// Delete from Spotlight search
		#if os(iOS)
		if #available(iOS 9.0, *) {
			deleteFromSpotlight(game: game)
		}
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
			try FileManager.default.removeItem(at: $0.url )
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
			let file = romDirectory.appendingPathComponent( $0.lastPathComponent, isDirectory: false)
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

@available(iOS 9.0, *)
extension RomDatabase {
	private func deleteFromSpotlight(game: PVGame) {
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [game.spotlightUniqueIdentifier], completionHandler: { (error) in
			if let error = error {
				print("Error deleting game spotlight item: \(error)")
			} else {
				print("Game indexing deleted.")
			}
		})
	}

	private func deleteAllGamesFromSpotlight() {
		CSSearchableIndex.default().deleteAllSearchableItems { (error) in
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
    public func refresh() {
        realm.refresh()
    }
}

// MARK: - Convenience Accessors
public protocol PVObject {}
public extension PVObject where Self : Object {
    static var all: Results<Self> {
        return RomDatabase.sharedInstance.all(Self.self)
    }

    func add(update: Bool = false) throws {
        try RomDatabase.sharedInstance.add(self, update: update)
    }

    static func deleteAll() throws {
        try RomDatabase.sharedInstance.deleteAll(Self.self)
    }

    func delete() throws {
        try RomDatabase.sharedInstance.delete(self)
    }

    static func with(primaryKey: String) -> Self? {
        return RomDatabase.sharedInstance.object(ofType: Self.self, wherePrimaryKeyEquals: primaryKey)
    }
}

// Now all Objects can use PVObject methods
extension Object: PVObject {}

public protocol PVFiled {
    var file: PVFile? { get }
}
public extension PVFiled where Self : Object {
    var missing: Bool {
        return file == nil || file!.missing
    }

    var md5: String? {
        guard let file = file else {
            return nil
        }
        return file.md5
    }
}
