//
//  PVUser.swift
//  Provenance
//
//  Created by Joe Mattiello on 11/20/2022.
//  Copyright (c) 2022 Provenance EMU. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers
public final class PVUser: Object {
    @Persisted public var uuid: String = ""
    @Persisted public var name: String = ""

    // Remote info
    @Persisted public var isPatron: Bool = false
    @Persisted public var savesAccess: Bool = false

    @Persisted public var lastSeen: Date = Date()
}

// PVLibrary - Network
public extension PVUser {
//    var isOnline: Bool {
//        return isLocal ? true : false
//    }
}
