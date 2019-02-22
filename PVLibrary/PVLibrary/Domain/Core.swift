//
//  Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift

public struct Core: Codable {
    public let identifier: String
    public let principleClass: String
    #warning("un-realm me")
    public var systems: [System] {
        let realm = try! Realm()
        let systems = realm.objects(PVSystem.self).filter { $0.cores.contains(where: {
            $0.identifier == self.identifier
        }) }.map {
            System(with: $0)
        }
        return systems.map { $0 }
    }

    public let project: CoreProject
}

extension Core: Equatable {
    public static func == (lhs: Core, rhs: Core) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

public struct CoreProject: Codable {
    public let name: String
    public let url: URL
    public let version: String
}
