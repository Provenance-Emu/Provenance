//
//  PVRecentGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift

public final class PVRecentGame: Object, Identifiable, PVLibraryEntry {
    @Persisted public var game: PVGame!
    @Persisted(indexed: true) public var lastPlayedDate: Date = Date()
    @Persisted public var core: PVCore?

    public convenience init(withGame game: PVGame, core: PVCore? = nil) {
        self.init()
        self.game = game
        self.core = core
    }
}
