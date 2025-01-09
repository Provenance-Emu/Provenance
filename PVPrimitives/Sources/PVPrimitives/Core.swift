//
//  Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

/// A Core is a collection of systems and metadata that are used to run a game
public struct Core: Codable, Sendable {
    
    
    /// Unique Identifier form a lookup table
    public let identifier: String
    
    /// The class name of the principle `Class`
    public let principleClass: String
    
    /// Is the core disabled
    public let disabled: Bool

    /// The systems that are provided to by this core
    public var systems: [System]
    
    /// The project that this core is associated
    public let project: CoreProject
    
    public init(identifier: String, principleClass: String, disabled: Bool, systems: [System], project: CoreProject) {
        self.identifier = identifier
        self.principleClass = principleClass
        self.disabled = disabled
        self.systems = systems
        self.project = project
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.principleClass = try container.decode(String.self, forKey: .principleClass)
        self.disabled = try container.decode(Bool.self, forKey: .disabled)
        self.systems = try container.decode([System].self, forKey: .systems)
        self.project = try container.decode(CoreProject.self, forKey: .project)
    }
}

extension Core: Equatable {
    public static func == (lhs: Core, rhs: Core) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
