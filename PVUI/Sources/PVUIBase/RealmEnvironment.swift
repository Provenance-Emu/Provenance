import Foundation
import RealmSwift
import SwiftUI
import PVLogging
import PVLibrary

/// Environment object to provide a shared Realm instance across the app
public class RealmEnvironment: ObservableObject {
    @Published public var realm: Realm?
    @Published public var romDatabase: RomDatabase
    
    public init(romDatabase: RomDatabase = RomDatabase.sharedInstance, realm: Realm? = nil) {
        // Use the shared RomDatabase instance
        self.romDatabase = RomDatabase.sharedInstance
        self.realm = realm ?? romDatabase.realm
        ILOG("RealmEnvironment: Using shared RomDatabase instance")
    }
    
    public func refresh() {
        // Refresh the realm from the shared RomDatabase
        romDatabase = RomDatabase.sharedInstance
        realm = romDatabase.realm
        RomDatabase.refresh()
        ILOG("RealmEnvironment: Refreshed shared RomDatabase instance")
    }
}
