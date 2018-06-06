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

@objcMembers public class PVLibrary: Object {
	dynamic var uuid : String = ""
	dynamic var name : String = ""

	dynamic var isLocal : Bool = true

	// Remote info
	dynamic var ipaddress : String = ""
	dynamic var domainname : String = ""
	dynamic var bonjourName : String = ""
	dynamic var port : Int = 7769 // prov on phone pad

	dynamic var lastSeen : Date = Date()

	var games = List<PVGame>()
}

// PVLibrary - Network
extension PVLibrary {
	var isOnline : Bool {
		return isLocal ? true : false
	}
}

@objcMembers public class PVRemoteFile: Object {

}
