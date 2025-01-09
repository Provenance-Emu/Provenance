//
//  PVCore+Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import PVPrimitives
import Foundation
import RealmSwift

// MARK: - Conversions
public extension Core {
    init(with core: PVCore) {
        let identifier = core.identifier
        let principleClass = core.principleClass
        let disabled = core.disabled
        // TODO: Supported systems
        let url = URL(string: core.projectURL) ?? URL(string: "https://provenance-emu.com")!
        ILOG("loadcore: \(core.projectName) class: \(core.principleClass) identifier: \(identifier) disable: \(disabled)")
        let project = CoreProject(name: core.projectName, url: url, version: core.projectVersion)
        let systems = Array(core.supportedSystems.map { $0.asDomain() })
        
        self.init(identifier: identifier, principleClass: principleClass, disabled: disabled, systems: systems, project: project)
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
            object.projectName = project.name
            object.projectVersion = project.version
            object.projectURL = project.url.absoluteString
            object.disabled = disabled

            Task {
                let realm = try! await Realm()
                let rmSystems = systems.compactMap { realm.object(ofType: PVSystem.self, forPrimaryKey: $0.identifier) }
                object.supportedSystems.append(objectsIn: rmSystems)
            }
        })
    }
}
