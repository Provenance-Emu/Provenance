//
//  User.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import SwiftData

@Model
public class User_Data {
    @Attribute(.unique) public var uuid: String = UUID().uuidString
    public var name: String = ""
    public var lastSeen: Date = Date()

    public init(uuid: String = UUID().uuidString, name: String = "", lastSeen: Date = Date()) {
        self.uuid = uuid
        self.name = name
        self.lastSeen = lastSeen
    }
}
