//
//  PVRecentGame.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/02/2018.
//  Copyright (c) 2018 JamSoft. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public final class PVRecentGame: Object, Identifiable, PVRecentGameLibraryEntry {
    
    @Persisted(wrappedValue: UUID().uuidString) public var id: String
    @Persisted public var game: PVGame!
    @Persisted(wrappedValue: Date(), indexed: true) public var lastPlayedDate: Date
    @Persisted public var core: PVCore?

    public convenience init(withGame game: PVGame, core: PVCore? = nil) {
        self.init()
        self.game = game
        self.core = core
    }
}
