//
//  CoreProject.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation


/// Data struture for a core project metadata
public struct CoreProject: Codable, Sendable {
    
    /// Name of the project
    public let name: String
    
    /// URL of the project
    public let url: URL
    
    /// Version of project included in app
    public let version: String
    
    
    /// Public init
    /// - Parameters:
    ///   - name: Name of the project
    ///   - url: Public URL of the project
    ///   - version: Version of the project
    public init(name: String, url: URL, version: String) {
        self.name = name
        self.url = url
        self.version = version
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.version = try container.decode(String.self, forKey: .version)
    }
}

// MARK: - Equatable
extension CoreProject: Equatable {
    public static func == (lhs: CoreProject, rhs: CoreProject) -> Bool {
        return lhs.name == rhs.name && lhs.version == rhs.version
    }
}
