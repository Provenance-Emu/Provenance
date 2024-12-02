//
//  Library.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData

//@Model
public class Library_Data {

    // Data
//    @Attribute(.unique)
    public var uuid: String = ""
    public var name: String = ""
    
    // Meta Data
    var isLocal: Bool = true
    
    // Remote info
    var ipaddress: String = ""
    var domainname: String = ""
    var bonjourName: String = ""
    var port: Int = 7769 // prov on phone pad
    
    var lastSeen: Date = Date()
    
    // Links
//    @Reference(to: Game_Data.self)
    var games: [Game_Data]
    
    init(uuid: String, name: String, isLocal: Bool, ipaddress: String, domainname: String, bonjourName: String, port: Int, lastSeen: Date, games: [Game_Data]) {
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
