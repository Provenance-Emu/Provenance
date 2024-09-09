//
//  PVGameLibrary+RxRealm.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

import RealmSwift
import RxSwift
import RxRealm
import PVRealm

/// PVGameLibrary Rx Extension
/// Ths implimentation forwards all calls to the database driver
extension PVGameLibrary: GameLibraryRxRealm where T == RealmDatabaseDriver {
    
    public var saveStates: SavesObservable { databaseDriver.saveStates }
    public var favorites: GamesObservable { databaseDriver.favorites }
    public var recents: RecentGamesObservable { databaseDriver.recents }
    public var mostPlayed: GamesObservable { databaseDriver.mostPlayed }
    
    public func search(for searchText: String) -> GamesObservable { databaseDriver.search(for: searchText) }
    
    public func searchResults(for searchText: String) -> Results<PVGame> { databaseDriver.searchResults(for: searchText) }
    
    /// System for identifier
    /// - Parameter identifier: ID String of the system
    /// - Returns: Optional matching PVSystem
    public func system(identifier: String) -> PVSystem? { database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: identifier) }
    
    /// Get all games for a System
    /// - Parameter systemIdentifier: ID String of the system to query
    /// - Returns: A query result with live updating as long as the reference is active
    public func gamesForSystem(systemIdentifier: String) -> Results<PVGame> { databaseDriver.gamesForSystem(systemIdentifier: systemIdentifier) }
    
    /// Systems sorted by Options -> RxRealm.Observable
    
    public typealias SystemStruct = PVGameLibrary<RealmDatabaseDriver>.System
    public typealias SystemObservable = Observable<SystemStruct>
    public typealias SystemArrayObservable = Observable<[SystemStruct]>
    
    /// Get all systems sorted by...
    /// - Parameter sortOptions: Sory options, .title, .importDate, .lastPlayed, .mostPlayed
    /// - Returns: An Observable of systems by the sort options that updates as ROMs are played or imported
    public func systems(sortedBy sortOptions: PVSettings.SortOptions) -> Observable<[PVGameLibrary<RealmDatabaseDriver>.System]> { databaseDriver.systems(sortedBy: sortOptions) }
}

public extension RxSwift.ObservableType where Element: Collection {
    func mapMany<R>(_ transform: @escaping (Element.Element) -> R?) -> Observable<[R]> { map { elements in elements.compactMap(transform) } }
}
