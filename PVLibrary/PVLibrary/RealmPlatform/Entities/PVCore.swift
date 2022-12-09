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
    public var supportedSystems = List<PVSystem>()

    public dynamic var projectName = ""
    public dynamic var projectURL = ""
    public dynamic var projectVersion = ""
    public dynamic var disabled = false

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
}

// MARK: - Conversions

internal extension Core {
//    init(with core: PVCore) {
//        let identifier = core.identifier
//        let principleClass = core.principleClass
//        let systems : [System] = {
//                let realm = try! Realm()
//                let systems = realm.objects(PVSystem.self).filter { $0.cores.contains(where: {
//                    $0.identifier == identifier
//                }) }.map {
//                    System(with: $0)
//                }
//                return systems.map { $0 }
//        }()
//
//        // TODO: Supported systems
//        let project = CoreProject(name: core.projectName, url: URL(string: core.projectURL)!, version: core.projectVersion)
//        self.init(identifier: identifier, principleClass: principleClass, systems: systems, project: project)
//    }
    init(with core: PVCore) {
        identifier = core.identifier
        principleClass = core.principleClass
        disabled = core.disabled
        // TODO: Supported systems
		DLOG("\(core.projectName)")
		print("loadcore: \(core.projectName) class: \(core.principleClass)")
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
            object.disabled = disabled
        })
    }
}
