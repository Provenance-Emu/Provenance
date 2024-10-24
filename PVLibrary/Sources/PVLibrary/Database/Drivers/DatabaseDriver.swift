//
//  DatabaseDriver.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/25/24.
//

public protocol DatabaseDriverDataTypes<GameType, SystemType, SaveType, RecentGameType> {
    associatedtype GameType: Any
    associatedtype SystemType: Any
    associatedtype SaveType: Any
    associatedtype RecentGameType: Any
}

public protocol DatabaseDriver: DatabaseDriverDataTypes {
    func system(identifier: String) -> SystemType?
    func game(identifier: String) -> GameType?
    
    init(database: RomDatabase)
}

/// PVGameLibrary Realm Extension
/// Ths implimentation forwards al calls to the database driver
extension PVGameLibrary: DatabaseDriverDataTypes {
    public typealias GameType = T.GameType
    public typealias SystemType = T.SystemType
    public typealias SaveType = T.SaveType
    public typealias RecentGameType = T.RecentGameType
}
