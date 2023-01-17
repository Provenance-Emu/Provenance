//
//  DatabaseManager.swift
//  AltStore
//
//  Created by Riley Testut on 5/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

public class DatabaseManager
{
    public static let shared: DatabaseManager = DatabaseManager(dataManager: Keychain.shared)
    
    public private(set) var databaseDataManager: DatabaseDataManager
    
    public required init(dataManager databaseDataManager: DatabaseDataManager) {
        self.databaseDataManager = databaseDataManager
    }
}

public extension DatabaseManager {
    func start(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    func signOut(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}

public extension DatabaseManager {
    func patreonAccount() -> PatreonAccount? {
        guard let patreonAccountID = Keychain.shared.patreonAccountID else { return nil }
        guard let patreonAccount: PatreonAccount = databaseDataManager.patreonAccounts?.first(where: {
            $0.identifier == patreonAccountID
        }) else {
            return nil
        }
        return patreonAccount
    }
}
