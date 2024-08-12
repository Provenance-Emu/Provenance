//
//  PVObject.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

// MARK: - Convenience Accessors

public protocol PVObject {}
public extension PVObject where Self: Object {
    public
    static var all: Results<Self> {
        return RomDatabase.sharedInstance.all(Self.self)
    }

    public
    func add(update: Bool = false) throws {
        try RomDatabase.sharedInstance.add(self, update: update)
    }
    
    public
    func delete() throws {
        try RomDatabase.sharedInstance.delete(self.warmUp())
    }

    public
    func warmUp() -> Self {
        if self.isFrozen, let thawed = self.thaw() {
            return thawed
        }
        return self
    }

    public
    static func with(primaryKey: String) -> Self? {
        return RomDatabase.sharedInstance.object(ofType: Self.self, wherePrimaryKeyEquals: primaryKey)
    }
}

public
protocol DetachableObject: AnyObject {
    func detached() -> Self
}

// Now all Objects can use PVObject methods
extension Object: PVObject {
    public func detached() -> Self {
        let detached = type(of: self).init()
        for property in objectSchema.properties {
            guard let value = value(forKey: property.name) else { continue }
            if let detachable = value as? DetachableObject {
                detached.setValue(detachable.detached(), forKey: property.name)
            } else {
                detached.setValue(value, forKey: property.name)
            }
        }
        return detached
    }
}
