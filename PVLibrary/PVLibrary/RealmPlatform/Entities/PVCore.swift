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

// MARK: - Conversions
internal extension Core {
    init(with core : PVCore) {
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
