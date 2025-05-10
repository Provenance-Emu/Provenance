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
        
        self.init(identifier: identifier, principleClass: principleClass, disabled: disabled, systems: systems, project: project, contentless: core.contentless)
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
        try! Realm().buildCore(from: self)
    }
}

public extension Realm {
    func buildCore(from core: Core) -> PVCore {
        if let existing = object(ofType: PVCore.self, forPrimaryKey: core.identifier) {
            return existing
        }

        return PVCore.build({ object in
            object.identifier = core.identifier
            object.principleClass = core.principleClass
            object.projectName = core.project.name
            object.projectVersion = core.project.version
            object.projectURL = core.project.url.absoluteString
            object.disabled = core.disabled
            object.contentless = core.contentless

            let rmSystems = core.systems.compactMap { self.object(ofType: PVSystem.self, forPrimaryKey: $0.identifier) }
            object.supportedSystems.append(objectsIn: rmSystems)
        })
    }
}
