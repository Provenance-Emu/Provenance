//
//  PVCore.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVLogging
import PVPrimitives

@objcMembers
public final class PVCore: RealmSwift.Object {
    public dynamic var identifier: String = ""
    public dynamic var principleClass: String = ""
    public var supportedSystems = List<PVSystem>()

    public dynamic var projectName = ""
    public dynamic var projectURL = ""
    public dynamic var projectVersion = ""
    public dynamic var disabled = false
    
    public var hasCoreClass: Bool {
        let _class: AnyClass? = NSClassFromString(principleClass)
        DLOG("Class: \(String(describing: _class)) for \(principleClass)")
        return _class != nil
    }

    // Reverse links
    public var saveStates = LinkingObjects(fromType: PVSaveState.self, property: "core")

    public convenience init(withIdentifier identifier: String, principleClass: String, supportedSystems: [PVSystem], name: String, url: String, version: String, disabled: Bool =  false) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        projectName = name
        projectURL = url
        projectVersion = version
        self.disabled = disabled
    }

    public override static func primaryKey() -> String? {
        return "identifier"
    }

    public override class func ignoredProperties() -> [String] {
        ["hasCoreClass"]
    }
}
