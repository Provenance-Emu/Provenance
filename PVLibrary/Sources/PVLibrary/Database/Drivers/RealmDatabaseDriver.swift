//
//  RealmDatabaseDriver.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/25/24.
//

import Foundation
import PVSupport
import RxSwift
import RealmSwift
import RxRealm
import PVLogging
import PVRealm
import Systems

@_exported public import PVSettings

public final class RealmDatabaseDriver: DatabaseDriver, GameLibraryRealm, GameLibraryRxRealm {

    /// DatabaseDriverDataTypes
    public typealias GameType = PVGame
    public typealias SystemType = PVSystem
    public typealias Savetype = PVSaveState
    public typealias RecentGame = PVRecentGame
    
    ///
    private let database: RomDatabase
    
    ///
    public lazy var saveStates: SavesObservable = {
        Observable
           .collection(from: self.saveStatesResults)
           .mapMany { $0 }
    }()

    ///
    public lazy var favorites: GamesObservable = {
        Observable
           .collection(from: self.favoritesResults)
           .mapMany { $0 }
    }()

    ///
    public lazy var recents: RecentGamesObservable = {
        Observable
           .collection(from: recentsResults)
           .mapMany { $0 }
    }()
    
    ///
    public lazy var mostPlayed: GamesObservable = {
        Observable
            .collection(from: self.mostPlayedResults)
            .mapMany { $0 }
    }()

    /// Save States
    public lazy var saveStatesResults: Results<PVSaveState> = {
        database
            .all(PVSaveState.self)
            .filter("game != nil && game.system != nil")
            .sorted(byKeyPath: #keyPath(PVSaveState.lastOpened),
                    ascending: false)
            .sorted(byKeyPath: #keyPath(PVSaveState.date),
                    ascending: false)
    }()
    
    ///
    public lazy var favoritesResults: Results<PVGame> = {
        database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
    }()
    
    ///
    public lazy var recentsResults: Results<PVRecentGame> = {
        database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
    }()
    
    ///
    public lazy var mostPlayedResults: Results<PVGame> = {
        database.all(PVGame.self).sorted(byKeyPath: #keyPath(PVGame.playCount), ascending: false)
    }()
    
    ///
    public lazy var activeSystems: Results<PVSystem> = {
        database.all(PVSystem.self, filter: NSPredicate(format: "games.@count > 0")).sorted(byKeyPath: #keyPath(PVSystem.name), ascending: true)
    }()

    
    /// Init a new RealmDatabaseDriver
    /// - Parameter database: The RomDatabase to query on.
    required public init(database: RomDatabase) {
        self.database = database
    }
    
    // MARK: - Query by Identifier

    /// Game for identifier
    /// - Parameter identifier: ID String of the game
    /// - Returns: Optional matching PVGame
    public func game(identifier: String) -> PVGame? {
        database.object(ofType: PVGame.self, wherePrimaryKeyEquals: identifier)
    }
 
    /// PVGame .isFavorite toggle
    /// - Returns: Completable for when finished
    public func toggleFavorite(for game: PVGame) -> Completable {
        Completable.create { observer in
            do {
                try self.database.writeTransaction {
                    game.isFavorite = !game.isFavorite
                    observer(.completed)
                }
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
}

/// System Query methods
///
extension RealmDatabaseDriver {
    
    /// System for identifier
    /// - Parameter identifier: ID String of the system
    /// - Returns: Optional matching PVSystem
    public func system(identifier: String) -> PVSystem? {
        database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: identifier)
    }
    
    /// Get all games for a System
    /// - Parameter systemIdentifier: ID String of the system to query
    /// - Returns: A query result with live updating as long as the reference is active
    public func gamesForSystem(systemIdentifier: String) -> Results<PVGame> {
        database.all(PVGame.self).filter(NSPredicate(format: "systemIdentifier == %@", argumentArray: [systemIdentifier]))
    }

    /// Systems sorted by Options -> RxRealm.Observable
    
    public typealias SystemStruct = PVGameLibrary<RealmDatabaseDriver>.System
    public typealias SystemObservable = Observable<SystemStruct>
    public typealias SystemArrayObservable = Observable<[SystemStruct]>
    
    /// Get all systems sorted by...
    /// - Parameter sortOptions: Sory options, .title, .importDate, .lastPlayed, .mostPlayed
    /// - Returns: An Observable of systems by the sort options that updates as ROMs are played or imported
    public func systems(sortedBy sortOptions: PVSettings.SortOptions) -> Observable<[PVGameLibrary<RealmDatabaseDriver>.System]> {
        let betaIDs: [SystemIdentifier] = SystemIdentifier.betas
        let unsuppotedIDs: [SystemIdentifier] = SystemIdentifier.unsupported
        
        return Observable
            .collection(from: database.all(PVSystem.self))
            .flatMapLatest({ systems -> SystemArrayObservable in
                // Here we actualy observe on the games for each system, since we want to update this when games are added or removed from a system
                Observable
                    .combineLatest(systems.map({ (pvSystem: PVSystem) -> SystemObservable in
                        // We read all the values from the realm-object here, and not in the `Observable.collection` below
                        // Not doing this makes the game crash when using refreshGameLibrary, since the pvSystem goes out of scope inside the closure, and thus we crash
                        let identifier = pvSystem.identifier
                        let manufacturer = pvSystem.manufacturer
                        let shortName = pvSystem.shortName
                        let isBeta = betaIDs.contains(pvSystem.enumValue)
                        let unsupported = unsuppotedIDs.contains(pvSystem.enumValue)
                        let sortedGames = pvSystem.games.sorted(by: sortOptions)
                        return Observable
                            .collection(from: sortedGames)
                            .mapMany { $0 }
                            .map({ games in
                                SystemStruct(
                                    identifier: identifier,
                                    manufacturer: manufacturer,
                                    shortName: shortName,
                                    isBeta: isBeta,
                                    unsupported: unsupported,
                                    sortedGames: games
                                )
                            })
                    }))
            })
            .map { systems in systems.sorted(by: sortOptions) }
    }
    
}

/// Searching methods
///
extension RealmDatabaseDriver {
    /// Search for Game by String ->RxRealm.Observable
    /// This is a wrapper for `searchResults(for: String)`
    /// In theory this shoud live update if searching while a background import is in progress (rarely)
    /// - Parameter searchText: Search text for title, genre, descirption, region, developer, publisher
    /// - Returns: Observable wrapper from Results as [PVGame]
    public func search(for searchText: String) -> Observable<[PVGame]> {
        return Observable.collection(from: searchResults(for: searchText)).mapMany { $0 }
    }

    /// Search for Game by Sttring -> RealmSwift.Results
    /// Searches for title only and also any of the following containing; genre, description, region, developer, publisher
    /// - Parameter searchText: Text to search for
    /// - Returns: Live updating results of PVGames
    public func searchResults(for searchText: String) -> Results<PVGame> {
        // Search first by title, and a broader search if that one's empty
        if searchText.count == 0 {
            return self.database.all(PVGame.self).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        } else {
            
            /// Search by title contains
            let titlePredicate = NSPredicate(
                format: "title CONTAINS[c] %@",
                argumentArray: [searchText])

            /// Search LIKE in genre, region, description, developer or publisher
            let searchPredicate = NSPredicate(
                format: "genres LIKE[c] %@ OR gameDescription CONTAINS[c] %@ OR regionName LIKE[c] %@ OR developer LIKE[c] %@ or publisher LIKE[c] %@",
                argumentArray: [searchText, searchText, searchText, searchText, searchText])
            
            let titleResults = self.database.all(PVGame.self, filter: titlePredicate)
            let generalresults = { return self.database.all(PVGame.self, filter: searchPredicate) }
            let results = !titleResults.isEmpty ? titleResults : generalresults()
            return results.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        }
    }
}

/// Clearing methods
///
extension RealmDatabaseDriver {
    
    /// Clear the library
    /// - Returns: Completable for when finished
    public func clearLibrary() -> Completable {
        Completable.create { observer in
            do {
                try self.database.deleteAll()
                observer(.completed)
            } catch {
                NSLog("Failed to delete all objects. \(error.localizedDescription)")
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    /// Clear all ROMs from the library
    /// - Returns: Completable for when finished
    public func clearROMs() -> Completable {
        Completable.create { observer in
            do {
                try self.database.deleteAllGames()
                observer(.completed)
            } catch {
                ELOG("Failed to delete all objects. \(error.localizedDescription)")
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
    
    /// Refrehes the library
    /// - Returns: Completable for when finished
    public func refreshLibrary() -> Completable {
        Completable.create { observer in
            self.database.refresh()
            observer(.completed)
            return Disposables.create()
        }
    }
}
