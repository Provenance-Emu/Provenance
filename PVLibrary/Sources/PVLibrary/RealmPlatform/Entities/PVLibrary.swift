//
//  PVGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift
@_exported import PVLogging

// Should use PVLibrary for all or make a PVRemoteLibrary?
// realm doesn't support subclasses, but we could use protocols
// to define default behavior - joe m

@objcMembers
public final class PVLibrary: Object {
    public dynamic var uuid: String = ""
    public dynamic var name: String = ""

    public dynamic var isLocal: Bool = true

    // Remote info
    public dynamic var ipaddress: String = ""
    public dynamic var domainname: String = ""
    public dynamic var bonjourName: String = ""
    public dynamic var port: Int = 7769 // prov on phone pad

    public dynamic var lastSeen: Date = Date()

    public private(set) var games = List<PVGame>()
}

// PVLibrary - Network
public extension PVLibrary {
    var isOnline: Bool {
        return isLocal ? true : false
    }
}

// @objcMembers public final class PVRemoteFile: Object {}
