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
    
    // Data
    @Attribute(.unique)
    public var id: String = UUID().uuidString

    public var date: Date = Date()
    public var isAutosave: Bool = false
    public var createdWithCoreVersion: String
    
    // Metadata
    
    public var lastOpened: Date?

    // References
//    @Reference(to: Game_Data.self)
    var game: Game_Data
//    @Reference(to: Core_Data.self)
    var core: Core_Data
//    @Reference(to: File_Data.self)
    var file: File_Data
//    @Reference(to: ImageFile_Data.self)
    var image: ImageFile_Data
    
    init(id: String, date: Date, isAutosave: Bool, createdWithCoreVersion: String, lastOpened: Date? = nil, game: Game_Data, core: Core_Data, file: File_Data, image: ImageFile_Data) {
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
