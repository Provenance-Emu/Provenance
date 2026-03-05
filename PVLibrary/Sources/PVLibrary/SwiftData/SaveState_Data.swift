//
//  SaveState.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData

@Model
public class SaveState_Data {
    @Attribute(.unique) public var id: String = UUID().uuidString

    public var date: Date = Date()
    public var isAutosave: Bool = false
    public var createdWithCoreVersion: String = ""

    // Metadata
    public var lastOpened: Date?

    // Many-to-one: the game this save belongs to (inverse of Game_Data.saveStates)
    public var game: Game_Data?

    // Many-to-one: the core used (inverse of Core_Data.saveStates)
    public var core: Core_Data?

    // One-to-one: save state file on disk (save state owns the file)
    @Relationship(deleteRule: .cascade)
    public var file: File_Data?

    // One-to-one: screenshot/thumbnail (save state owns the image)
    @Relationship(deleteRule: .cascade)
    public var image: ImageFile_Data?

    public init(id: String = UUID().uuidString, date: Date = Date(), isAutosave: Bool = false,
                createdWithCoreVersion: String = "", lastOpened: Date? = nil,
                game: Game_Data? = nil, core: Core_Data? = nil,
                file: File_Data? = nil, image: ImageFile_Data? = nil) {
        self.id = id
        self.date = date
        self.isAutosave = isAutosave
        self.createdWithCoreVersion = createdWithCoreVersion
        self.lastOpened = lastOpened
        self.game = game
        self.core = core
        self.file = file
        self.image = image
    }
}
#endif
