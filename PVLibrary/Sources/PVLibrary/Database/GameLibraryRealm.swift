//
//  GameLibraryRealm.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/26/24.
//

import RxRealm
import RealmSwift


/// PVGameLibrary protocol for Realm
public protocol GameLibraryRealm: DatabaseDriverDataTypes where Self.GameType == PVGame, Self.RecentGameType == PVRecentGame, Self.SaveType == PVSaveState, Self.SystemType == PVSystem {

    /// Save States
    var saveStatesResults: Results<SaveType> { get }

    /// Favorites
    var favoritesResults: Results<GameType> { get }
    
    /// Recently played
    var recentsResults: Results<RecentGameType> { get }
    
    /// Most Played
    var mostPlayedResults: Results<GameType> { get }
    
    /// Systems with games
    var activeSystems: Results<SystemType> { get }
}

extension PVGameLibrary: GameLibraryRealm where T: RealmDatabaseDriver {
    
    public var saveStatesResults: Results<PVSaveState> { databaseDriver.saveStatesResults }
    public var favoritesResults: Results<PVGame> { databaseDriver.favoritesResults }
    public var recentsResults: Results<PVRecentGame> { databaseDriver.recentsResults }
    public var mostPlayedResults: Results<PVGame> { databaseDriver.mostPlayedResults }
   
    public var activeSystems: Results<PVSystem> { databaseDriver.activeSystems }
}
