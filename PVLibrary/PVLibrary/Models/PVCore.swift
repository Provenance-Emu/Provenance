//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers
public final class PVCore: Object {
    dynamic public var identifier: String = ""
    dynamic public var principleClass: String = ""
    dynamic public var supportedSystems = List<PVSystem>()

    dynamic public var projectName = ""
    dynamic public var projectURL = ""
    dynamic public var projectVersion = ""

	// Reverse links
	public var saveStates = LinkingObjects(fromType: PVSaveState.self, property: "core")

    public convenience init(withIdentifier identifier: String, principleClass: String, supportedSystems: [PVSystem], name: String, url: String, version: String) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        self.projectName = name
        self.projectURL = url
        self.projectVersion = version
    }

    override public static func primaryKey() -> String? {
        return "identifier"
    }
}
