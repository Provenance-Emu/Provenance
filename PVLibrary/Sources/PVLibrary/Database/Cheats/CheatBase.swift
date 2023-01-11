//
//  CheatBase.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation

public struct CheatBase {
    fileprivate static let cheatDBURL: URL = {
        let bundle = Bundle.module //Bundle(for: CheatBase.self)
        let url = bundle.url(forResource: "cheatbase", withExtension: "sqlite")!
        return url
    }()

#if false
    fileprivate let databaseBackend: DatabaseBackendProtocol = GRDBBackend(sqliteDBPath: CheatBase.cheatDBURL)
#else
    fileprivate let databaseBackend: DatabaseBackendProtocol = SQLiteSwiftBackend(sqliteDBPath: CheatBase.cheatDBURL)
#endif
}
