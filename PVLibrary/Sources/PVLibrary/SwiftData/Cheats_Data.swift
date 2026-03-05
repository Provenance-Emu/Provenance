//
//  Cheats.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData

@Model
public class Cheats_Data {
    @Attribute(.unique) public var id: String = UUID().uuidString

    // Data
    public var code: String = ""
    public var enabled: Bool = false

    // Metadata
    public var date: Date = Date()
    public var lastOpened: Date?
    public var type: String = ""
    /// The emulator-specific code format identifier (e.g. "Game Shark", "Action Replay").
    public var codeType: String = ""
    public var createdWithCoreVersion: String = ""

    // Many-to-one: the game this cheat belongs to (inverse of Game_Data.cheats)
    public var game: Game_Data?

    // Many-to-one: the core this cheat is for
    public var core: Core_Data?

    // One-to-one: cheat file on disk (cheat owns the file)
    @Relationship(deleteRule: .cascade)
    public var file: File_Data?

    public init(code: String, enabled: Bool = false, date: Date = Date(),
                lastOpened: Date? = nil, type: String = "", codeType: String = "",
                createdWithCoreVersion: String = "",
                game: Game_Data? = nil, core: Core_Data? = nil, file: File_Data? = nil) {
        self.id = UUID().uuidString
        self.code = code
        self.enabled = enabled
        self.date = date
        self.lastOpened = lastOpened
        self.type = type
        self.codeType = codeType
        self.createdWithCoreVersion = createdWithCoreVersion
        self.game = game
        self.core = core
        self.file = file
    }
}
#endif
