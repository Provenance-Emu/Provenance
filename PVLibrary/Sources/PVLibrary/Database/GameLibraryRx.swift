//
//  GameLibraryRx.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/26/24.
//

import RxRealm
import PVSettings

/// PVGameLibrary protocol for RxRealm
public protocol GameLibraryRxRealm: GameLibraryRealm where Self.GameType == PVGame, Self.RecentGameType == PVRecentGame, Self.SaveType == PVSaveState, Self.SystemType == PVSystem {
    

    typealias SavesObservable = RxSwift.Observable<[SaveType]>
    typealias GamesObservable = RxSwift.Observable<[GameType]>
    typealias RecentGamesObservable = RxSwift.Observable<[PVRecentGame]>
    typealias SystemsObservable = RxSwift.Observable<[SystemType]>

    typealias GameLibrarySystem = PVGameLibrary<RealmDatabaseDriver>.System
    typealias GameLibrarySystemObservable = RxSwift.Observable<[PVGameLibrary<RealmDatabaseDriver>.System]>

    /// Latest Save States
    var saveStates: SavesObservable { get }
    
    /// Favorite games
    var favorites: GamesObservable { get }
    
    /// Recently played games
    var recents: RxSwift.Observable<[RecentGameType]> { get }
    
    /// Most Played games
    var mostPlayed: GamesObservable { get }
    
    // Methods
    
    /// Search for games
    func search(for searchText: String) -> GamesObservable
    
    /// Systems sorted by sort options
    /// - Parameter sortOptions: `PVSettings.SortOptions`
    /// - Returns: `RxSwift.Observable<[SaveType]>`
    func systems(sortedBy sortOptions: PVSettings.SortOptions) ->  Observable<[PVGameLibrary<RealmDatabaseDriver>.System]> 
}
