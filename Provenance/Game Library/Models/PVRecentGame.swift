//
//  PVRecentGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class PVRecentGame: Object, PVLibraryEntry {

    dynamic var game: PVGame!
    dynamic var lastPlayedDate: Date = Date()

    override public static func indexedProperties() -> [String] {
        return ["lastPlayedDate"]
    }

    public convenience init(withGame game: PVGame) {
        self.init()
        self.game = game
    }
}
