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
    public dynamic var uuid: String = ""
    public dynamic var name: String = ""

    // Remote info
    public dynamic var isPatron: Bool = false
    public dynamic var savesAccess: Bool = false

    public dynamic var lastSeen: Date = Date()
}

// PVLibrary - Network
public extension PVUser {
//    var isOnline: Bool {
//        return isLocal ? true : false
//    }
}
