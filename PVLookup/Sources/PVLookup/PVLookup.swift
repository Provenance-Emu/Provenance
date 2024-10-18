//
//  PVLookup.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

#if canImport(TheGamesDB)
@_exported import TheGamesDB
#endif
#if canImport(OpenVGDB)
@_exported import OpenVGDB
#endif
#if canImport(ShiraGame)
@_exported import ShiraGame
#endif

public enum PVLookup {
//    case theGamesDB(TheGamesDB.Lookup)
//    case openVGDB(OpenVGDB.Lookup)
//    case shireGame(ShireGame.Lookup)
}

public enum LocalDatabases: CaseIterable {
#if canImport(OpenVGDB)
    case openVGDB
#endif
#if canImport(ShiraGame)
    case shireGame
#endif
}

public enum RemoteDatabases: CaseIterable {
#if canImport(TheGamesDB)
    case theGamesDB
#endif
}
