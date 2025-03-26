import Foundation
import RealmSwift
import SwiftUI
import PVLogging
import PVLibrary

/// Environment object to provide a shared Realm instance across the app
class RealmEnvironment: ObservableObject {
    @Published var realm: Realm?
    @Published var romDatabase: RomDatabase
    
    init() {
        // Use the shared RomDatabase instance
        romDatabase = RomDatabase.sharedInstance
        realm = romDatabase.realm
        ILOG("RealmEnvironment: Using shared RomDatabase instance")
    }
    
    func refresh() {
        // Refresh the realm from the shared RomDatabase
        romDatabase = RomDatabase.sharedInstance
        realm = romDatabase.realm
        RomDatabase.refresh()
        ILOG("RealmEnvironment: Refreshed shared RomDatabase instance")
    }
}
