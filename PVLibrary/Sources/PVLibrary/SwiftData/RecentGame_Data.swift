//
//  RecentGame_Data.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import SwiftData

@Model
public class RecentGame_Data {
    @Attribute(.unique) public var id: String = UUID().uuidString

    // Many-to-one: the game played
    public var game: Game_Data?
    public var lastPlayedDate: Date = Date()
    // Many-to-one: core used for this play session
    public var core: Core_Data?

    public init(id: String = UUID().uuidString, game: Game_Data? = nil,
                lastPlayedDate: Date = Date(), core: Core_Data? = nil) {
        self.id = id
        self.game = game
        self.lastPlayedDate = lastPlayedDate
        self.core = core
    }
}
