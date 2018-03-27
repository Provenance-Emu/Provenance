//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class PVSaveState: Object {

    dynamic var game: PVGame!
    dynamic var file: PVFile!
    dynamic var date: Date = Date()
    dynamic var image: PVImageFile?
    dynamic var isAutosave: Bool = false

    convenience init(withGame game: PVGame, file: PVFile, image: PVImageFile? = nil, isAutosave: Bool = false) {
        self.init()
        self.game  = game
        self.file  = file
        self.image = image
        self.isAutosave = isAutosave
    }
}
