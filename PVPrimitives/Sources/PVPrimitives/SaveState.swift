//
//  SaveState.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public protocol SaveStateInfoProvider {
    var id: String { get }
    var game: Game { get }
    var core: Core { get }
    var file: FileInfo { get }
    var date: Date { get }
    var lastOpened: Date? { get }
    var image: LocalFile? { get }
    var isAutosave: Bool { get }
}

public struct SaveState: SaveStateInfoProvider, Codable, Sendable {
    public let id: String
    public let game: Game
    public let core: Core
    public let file: FileInfo
    public let date: Date
    public let lastOpened: Date?
    public let image: LocalFile?
    public let isAutosave: Bool
    
    public init(id: String, game: Game, core: Core, file: FileInfo, date: Date, lastOpened: Date?, image: LocalFile?, isAutosave: Bool) {
        self.id = id
        self.game = game
        self.core = core
        self.file = file
        self.date = date
        self.lastOpened = lastOpened
        self.image = image
        self.isAutosave = isAutosave
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.game = try container.decode(Game.self, forKey: .game)
        self.core = try container.decode(Core.self, forKey: .core)
        self.file = try container.decode(FileInfo.self, forKey: .file)
        self.date = try container.decode(Date.self, forKey: .date)
        self.lastOpened = try container.decodeIfPresent(Date.self, forKey: .lastOpened)
        self.image = try container.decodeIfPresent(LocalFile.self, forKey: .image)
        self.isAutosave = try container.decode(Bool.self, forKey: .isAutosave)
    }
}

extension SaveState: Equatable {
    public static func == (lhs: SaveState, rhs: SaveState) -> Bool {
        return lhs.id == rhs.id
    }
}

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers
@available(iOS 16.0, *)
extension SaveState: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .savestate)
    }
}
#endif
