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
    private enum CodingKeys: String, CodingKey {
        case identifier, principleClass, disabled, systems, project, contentless, supportedCheatTypes
    }



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

    /// Is the core a contentless core, can it run without a rom?
    public let contentless: Bool

    /// The cheat code formats supported by this core.
    public let supportedCheatTypes: [CheatCodeTypes]

    /// Raw strings preserved from the decoded payload so that unrecognized
    /// future values survive encode/decode round-trips without being dropped.
    private let rawSupportedCheatTypeStrings: [String]

    public init(identifier: String, principleClass: String, disabled: Bool = false, systems: [System], project: CoreProject, contentless: Bool = false, supportedCheatTypes: [CheatCodeTypes] = []) {
        self.identifier = identifier
        self.principleClass = principleClass
        self.disabled = disabled
        self.systems = systems
        self.project = project
        self.contentless = contentless
        self.supportedCheatTypes = supportedCheatTypes
        self.rawSupportedCheatTypeStrings = supportedCheatTypes.map { $0.stringValue }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.principleClass = try container.decode(String.self, forKey: .principleClass)
        self.disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
        self.systems = try container.decode([System].self, forKey: .systems)
        self.project = try container.decode(CoreProject.self, forKey: .project)
        self.contentless = try container.decodeIfPresent(Bool.self, forKey: .contentless) ?? false
        // Preserve the original raw strings so unknown future values survive re-encoding.
        // The typed array is derived via compactMap; unrecognized strings are dropped from
        // it but kept in rawSupportedCheatTypeStrings for lossless round-trip encoding.
        let strings = try container.decodeIfPresent([String].self, forKey: .supportedCheatTypes) ?? []
        self.rawSupportedCheatTypeStrings = strings
        self.supportedCheatTypes = strings.compactMap { CheatCodeTypes(string: $0) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(principleClass, forKey: .principleClass)
        try container.encode(disabled, forKey: .disabled)
        try container.encode(systems, forKey: .systems)
        try container.encode(project, forKey: .project)
        try container.encode(contentless, forKey: .contentless)
        // Re-encode the original raw strings (not the typed enum's stringValue) so that
        // any unrecognized future values decoded from disk are not silently discarded.
        try container.encode(rawSupportedCheatTypeStrings, forKey: .supportedCheatTypes)
    }
}

extension Core: Equatable {
    public static func == (lhs: Core, rhs: Core) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
