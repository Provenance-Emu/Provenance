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

public struct CoreProject : Codable {
	public let name : String
	public let url : URL
	public let version : String
}

public struct Core : Codable {
	public let identifier : String
	public var systems : [System] {
		let realm = try! Realm()
		let systems = realm.objects(PVSystem.self).filter { $0.cores.contains(where: {
			$0.identifier == self.identifier
		}) }.map {
			System($0)
		}
		return systems.map {$0}
	}

	public let project : CoreProject
}

extension Core : Equatable {
	public static func == (lhs: Core, rhs: Core) -> Bool {
		return lhs.identifier == rhs.identifier
	}}

public extension Core {
	public init(with core : PVCore) {
		identifier = core.identifier
		project = CoreProject(name: core.projectName, url: URL(string: core.projectURL)!, version: core.projectVersion)
	}
}
