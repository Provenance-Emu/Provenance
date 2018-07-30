//
//  PVGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift

// Should use PVLibrary for all or make a PVRemoteLibrary?
// realm doesn't support subclasses, but we could use protocols
// to define default behavior - joe m

@objcMembers
public final class PVLibrary: Object {
	dynamic public var uuid : String = ""
	dynamic public var name : String = ""

	dynamic public var isLocal : Bool = true

	// Remote info
	dynamic public var ipaddress : String = ""
	dynamic public var domainname : String = ""
	dynamic public var bonjourName : String = ""
	dynamic public var port : Int = 7769 // prov on phone pad

	dynamic public var lastSeen : Date = Date()

	public private(set) var games = List<PVGame>()
}

// PVLibrary - Network
public extension PVLibrary {
	public var isOnline : Bool {
		return isLocal ? true : false
	}
}

@objcMembers public class PVRemoteFile: Object {

}
