//
//  Library.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData

@Model
public class Library_Data {
    @Attribute(.unique) public var uuid: String = UUID().uuidString
    public var name: String = ""

    // Meta Data
    public var isLocal: Bool = true

    // Remote info
    public var ipaddress: String = ""
    public var domainname: String = ""
    public var bonjourName: String = ""
    public var port: Int = 7769 // prov on phone pad

    public var lastSeen: Date = Date()

    // Many-to-many: libraries contain games (inverse declared on Game_Data.libraries)
    @Relationship(inverse: \Game_Data.libraries)
    public var games: [Game_Data] = []

    public init(uuid: String = UUID().uuidString, name: String = "", isLocal: Bool = true,
                ipaddress: String = "", domainname: String = "", bonjourName: String = "",
                port: Int = 7769, lastSeen: Date = Date(), games: [Game_Data] = []) {
        self.uuid = uuid
        self.name = name
        self.isLocal = isLocal
        self.ipaddress = ipaddress
        self.domainname = domainname
        self.bonjourName = bonjourName
        self.port = port
        self.lastSeen = lastSeen
        self.games = games
    }
}
#endif
