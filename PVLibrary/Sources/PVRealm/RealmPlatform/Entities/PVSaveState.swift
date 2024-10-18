//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
import PVPrimitives

@objcMembers
public final class PVSaveState: RealmSwift.Object, Identifiable, Filed, LocalFileProvider {
    public dynamic var id = UUID().uuidString
    public dynamic var game: PVGame!
    public dynamic var core: PVCore!
    public dynamic var file: PVFile!
    public dynamic var date: Date = Date()
    public dynamic var lastOpened: Date?
    public dynamic var image: PVImageFile?
    public dynamic var isAutosave: Bool = false

    public dynamic var createdWithCoreVersion: String!

    public convenience init(withGame game: PVGame, core: PVCore, file: PVFile, image: PVImageFile? = nil, isAutosave: Bool = false) {
        self.init()
        self.game = game
        self.file = file
        self.image = image
        self.isAutosave = isAutosave
        self.core = core
        createdWithCoreVersion = core.projectVersion
    }

    public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
        return lhs.file.url == rhs.file.url
    }

    public override static func primaryKey() -> String? {
        return "id"
    }
}
