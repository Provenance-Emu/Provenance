//
//  EmulatorFileProviderItem.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//


import FileProvider
import UniformTypeIdentifiers

class EmulatorFileProviderItem: NSObject, NSFileProviderItem {
    
    // MARK: - Properties
    
    let identifier: NSFileProviderItemIdentifier
    let parentIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let gameSystem: GameSystem
    let fileSize: Int64
    let creationDate: Date?
    let contentModificationDate: Date?
    
    // MARK: - Initializer
    
    init(identifier: NSFileProviderItemIdentifier,
         parentIdentifier: NSFileProviderItemIdentifier,
         filename: String,
         gameSystem: GameSystem,
         fileSize: Int64,
         creationDate: Date,
         contentModificationDate: Date) {
        self.identifier = identifier
        self.parentIdentifier = parentIdentifier
        self.filename = filename
        self.gameSystem = gameSystem
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.contentModificationDate = contentModificationDate
        super.init()
    }
    
    // MARK: - NSFileProviderItem Protocol
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return identifier
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return parentIdentifier
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        return [.allowsReading, .allowsEvicting]
    }
    
    var documentSize: NSNumber? {
        return NSNumber(value: fileSize)
    }
    
    var contentType: UTType {
        switch gameSystem {
        case .nes:
            return UTType("com.example.nes-rom")!
        case .snes:
            return UTType("com.example.snes-rom")!
        case .gba:
            return UTType("com.example.gba-rom")!
        // Add more cases for other game systems
        default:
            return UTType.data
        }
    }
    
    var lastUsedDate: Date? {
        // You might want to track this separately
        return contentModificationDate
    }
    
    var tagData: Data? {
        // You can use this to store custom metadata
        return gameSystem.rawValue.data(using: .utf8)
    }
    
    // MARK: - Helper Methods
    
    func makeFileURL() -> URL {
        // This should return the actual file URL for the ROM
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(filename)
    }
}

// MARK: - Supporting Types

enum GameSystem: String {
    case nes = "Nintendo Entertainment System"
    case snes = "Super Nintendo"
    case gba = "Game Boy Advance"
    // Add more game systems as needed
}
