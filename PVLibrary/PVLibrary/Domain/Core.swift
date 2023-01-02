//
//  Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

public struct Core: Codable, Hashable {
    static var systemsCache = [String: [System]]()
    
    public let identifier: String
    public let principleClass: String
//    public let systems: [System]
    public let disabled: Bool
    public let requiresJIT: Bool
    public let supportsJIT: Bool
    
    public var systems: [System] {
        if let systems = Core.systemsCache[identifier] {
            return systems
        }
        let realm = try! Realm()
        let systems = realm.objects(PVSystem.self).filter { $0.cores.contains(where: {
            $0.identifier == self.identifier
        }) }.map {
            System(with: $0)
        }
        let mapped: [System] = systems.map { $0 }
        Core.systemsCache[identifier] = mapped
        return mapped
    }
    public let project: CoreProject

//    public init(identifier: String, principleClass: String, systems: [System], project: CoreProject) {
//        self.identifier = identifier
//        self.principleClass = principleClass
//        self.systems = systems
//        self.project = project
//    }
}

extension Core: Equatable {
    public static func == (lhs: Core, rhs: Core) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

public struct CoreProject: Codable, Hashable {
    public let name: String
    public let url: URL
    public let version: String
}

extension CoreProject: Equatable {
    public static func == (lhs: CoreProject, rhs: CoreProject) -> Bool {
        return lhs.name == rhs.name
    }
}
