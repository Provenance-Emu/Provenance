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
    @Persisted public var uuid: String = ""
    @Persisted public var name: String = ""

    @Persisted public var isLocal: Bool = true

    // Remote info
    @Persisted public var ipaddress: String = ""
    @Persisted public var domainname: String = ""
    @Persisted public var bonjourName: String = ""
    @Persisted public var port: Int = 7769 // prov on phone pad

    @Persisted public var lastSeen: Date = Date()

    @Persisted public private(set) var games: List<PVGame>
}

// PVLibrary - Network
public extension PVLibrary {
    var isOnline: Bool {
        return isLocal ? true : false
    }
}

// @objcMembers public final class PVRemoteFile: Object {}
