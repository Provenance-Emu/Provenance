//
//  ManagedPatron.swift
//  PVPatreon
//
//  Created by Joseph Mattiello on 9/27/24.
//

import SwiftData

public class ManagedPatron: Codable, Identifiable {
    public var name: String
    public var id: String
    
    init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}

public extension Patron {
    var managedPatron: ManagedPatron {
        .init(name: name, id: id)
    }
}
