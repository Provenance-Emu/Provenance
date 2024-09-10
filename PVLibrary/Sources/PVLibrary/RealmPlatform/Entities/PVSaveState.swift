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
import PVLibraryPrimitives

@objcMembers
public final class PVSaveState: Object, Identifiable, Filed, LocalFileProvider {
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

    public class func delete(_ state: PVSaveState) throws {
        do {
            // Temp store these URLs
            let fileURL = state.file.url
            let imageURl = state.image?.url

            let database = RomDatabase.sharedInstance
            try database.delete(state)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(atPath: fileURL.path)
            } else {
                WLOG("PVSaveState:Delete:SaveState Not Found at \(fileURL.path)")
            }
            if let imageURl = imageURl, FileManager.default.fileExists(atPath: imageURl.path){
                try FileManager.default.removeItem(at: imageURl)
            }
            if FileManager.default.fileExists(atPath: fileURL.path.appending(".json")) {
                try FileManager.default.removeItem(atPath: fileURL.path.appending(".json"))
            }
        } catch {
            ELOG("PVSaveState:Delete:Failed to delete PVState")
            throw error
        }
    }

    public dynamic var isNewestAutosave: Bool {
        guard isAutosave, let game = game, let newestSave = game.autoSaves.first else {
            return false
        }

        let isNewest = newestSave == self
        return isNewest
    }

    public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
        return lhs.file.url == rhs.file.url
    }

    public override static func primaryKey() -> String? {
        return "id"
    }
}
