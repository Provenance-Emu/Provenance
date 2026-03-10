//
//  PVObject+RealmExt.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import RealmSwift
import PVRealm

public extension PVObject where Self: RealmSwift.Object {

    /// Opens the migration-aware Realm configuration even during early startup.
    static var all: Results<Self> {
        let realm = try! Realm(configuration: RealmConfiguration.realmConfig)
        return realm.objects(Self.self)
    }

    func add(update: Bool = false) throws {
        try RomDatabase.sharedInstance.add(self, update: update)
    }

    func delete() throws {
        try RomDatabase.sharedInstance.delete(self.warmUp())
    }

    func warmUp() -> Self {
        if self.isFrozen, let thawed = self.thaw() {
            return thawed
        }
        return self
    }

    static func with(primaryKey: String) -> Self? {
        return RomDatabase.sharedInstance.object(ofType: Self.self, wherePrimaryKeyEquals: primaryKey)
    }
}
