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
    public dynamic var identifier: String = ""
    public dynamic var principleClass: String = ""
    public dynamic var supportedSystems = List<PVSystem>()

    public dynamic var projectName = ""
    public dynamic var projectURL = ""
    public dynamic var projectVersion = ""

    // Reverse links
    public var saveStates = LinkingObjects(fromType: PVSaveState.self, property: "core")

    public convenience init(withIdentifier identifier: String, principleClass: String, supportedSystems: [PVSystem], name: String, url: String, version: String) {
        self.init()
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems.removeAll()
        self.supportedSystems.append(objectsIn: supportedSystems)
        projectName = name
        projectURL = url
        projectVersion = version
    }

    public override static func primaryKey() -> String? {
        return "identifier"
    }
}

// MARK: - Conversions

internal extension Core {
    init(with core: PVCore) {
        identifier = core.identifier
        principleClass = core.principleClass
        // TODO: Supported systems
        project = CoreProject(name: core.projectName, url: URL(string: core.projectURL)!, version: core.projectVersion)
    }
}

extension PVCore: DomainConvertibleType {
    public typealias DomainType = Core

    public func asDomain() -> Core {
        return Core(with: self)
    }
}

extension Core: RealmRepresentable {
    public var uid: String {
        return identifier
    }

    public func asRealm() -> PVCore {
        let realm = try! Realm()
        if let existing = realm.object(ofType: PVCore.self, forPrimaryKey: identifier) {
            return existing
        }

        return PVCore.build({ object in
            object.identifier = identifier
            object.principleClass = principleClass
            let realm = try! Realm()
            let rmSystems = systems.compactMap { realm.object(ofType: PVSystem.self, forPrimaryKey: $0.identifier) }
            object.supportedSystems.append(objectsIn: rmSystems)
            object.projectName = project.name
            object.projectVersion = project.version
            object.projectURL = project.url.absoluteString
        })
    }
}
