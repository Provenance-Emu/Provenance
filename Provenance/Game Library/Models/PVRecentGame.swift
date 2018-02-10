//
//  PVRecentGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import RealmSwift

public class PVRecentGame : Object, PVLibraryEntry {

    @objc dynamic var game : PVGame?
    @objc dynamic var lastPlayedDate : Date = Date()

    override public static func indexedProperties() -> [String] {
        return ["lastPlayedDate"]
    }
    
    public convenience init(withGame game: PVGame) {
        self.init()
        self.game = game
    }
}
