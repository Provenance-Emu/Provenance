//
//  User.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData

#if !os(tvOS)
@Model
#endif
public class User_Data {
    // Data
#if !os(tvOS)
    @Attribute(.unique)
#endif
    public var uuid: String = UUID().uuidString
    
    public var name: String = ""

    // Meta data
    public var lastSeen: Date = Date()
    
    init(uuid: String, name: String, lastSeen: Date) {
        self.uuid = uuid
        self.name = name
        self.lastSeen = lastSeen
    }
}
#endif
