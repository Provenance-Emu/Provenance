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
    dynamic var version : String = ""
    dynamic var supportedSystems = List<PVSystem>()
    
    dynamic var projectName = ""
    dynamic var projectURL = ""
    
    override public static func primaryKey() -> String? {
        return "identifier"
    }
}
