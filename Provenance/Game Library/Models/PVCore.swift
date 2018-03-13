//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class PVCore : Object {
    dynamic var identifier : String = ""
    var supportSystems = List<PVSystem>()
    
    override public static func primaryKey() -> String? {
        return "identifier"
    }
}
