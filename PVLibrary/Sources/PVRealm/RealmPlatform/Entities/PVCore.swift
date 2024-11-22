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
public final class PVCore: RealmSwift.Object, Identifiable {
    @Persisted(primaryKey: true) public var identifier: String = ""
    @Persisted public var principleClass: String = ""
    @Persisted public var supportedSystems: List<PVSystem>

    @Persisted public var projectName = ""
    @Persisted public var projectURL = ""
    @Persisted public var projectVersion = ""
    @Persisted public var disabled = false
    @Persisted public var appStoreDisabled = false

    public var hasCoreClass: Bool {
        let _class: AnyClass? = NSClassFromString(principleClass)
        DLOG("Class: \(String(describing: _class)) for \(principleClass)")
        return _class != nil
    }

    // Reverse links
    @Persisted(originProperty: "core") public var saveStates: LinkingObjects<PVSaveState>

    public convenience init(withIdentifier identifier: String, principleClass: String, supportedSystems: [PVSystem], name: String, url: String, version: String, disabled: Bool =  false, appStoreDisabled: Bool = false) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        projectName = name
        projectURL = url
        projectVersion = version
        self.disabled = disabled
        self.appStoreDisabled = appStoreDisabled
    }

    public override class func ignoredProperties() -> [String] {
        ["hasCoreClass", "id"]
    }
    
    public var id: String {
        return identifier
    }
}
