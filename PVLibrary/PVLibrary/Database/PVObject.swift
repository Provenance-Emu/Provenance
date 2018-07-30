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
public extension PVObject where Self : Object {
	public static var all: Results<Self> {
		return RomDatabase.sharedInstance.all(Self.self)
	}

	public func add(update: Bool = false) throws {
		try RomDatabase.sharedInstance.add(self, update: update)
	}

	public static func deleteAll() throws {
		try RomDatabase.sharedInstance.deleteAll(Self.self)
	}

	public func delete() throws {
		try RomDatabase.sharedInstance.delete(self)
	}

	public static func with(primaryKey: String) -> Self? {
		return RomDatabase.sharedInstance.object(ofType: Self.self, wherePrimaryKeyEquals: primaryKey)
	}
}

// Now all Objects can use PVObject methods
extension Object: PVObject {}
