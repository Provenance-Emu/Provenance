//
//  Cheats.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData

//@Model
public class Cheats_Data {
//    @Attribute(.unique)
    public var id = UUID().uuidString

    // Data
    public var code: String!
    public var enabled: Bool = false

    // Metadata
    public var date: Date = Date()
    public var lastOpened: Date?
    public var type: String!
    public var createdWithCoreVersion: String!

    // References
//    @Reference(to: Game_Data.self)
    public var game: Game_Data
//    @Reference(to: Core_Data.self)
    public var core: Core_Data
//    @Reference(to: File_Data.self)
    public var file: File_Data
    
    init(code: String,
         enabled: Bool = false,
         date: Date = Date(),
         lastOpened: Date? = nil,
         type: String,
         createdWithCoreVersion: String,
         game: Game_Data,
         core: Core_Data,
         file: File_Data) {
        self.id = UUID().uuidString
        self.code = code
        self.enabled = enabled
        self.date = date
        self.lastOpened = lastOpened
        self.type = type
        self.createdWithCoreVersion = createdWithCoreVersion
        self.game = game
        self.core = core
        self.file = file
    }
}
#endif
