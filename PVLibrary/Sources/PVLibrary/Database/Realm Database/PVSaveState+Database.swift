//
//  func.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import PVRealm
import Foundation
import RealmSwift
import PVLogging

public extension PVSaveState {
    class func delete(_ state: PVSaveState) throws {
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

    dynamic var isNewestAutosave: Bool {
        guard isAutosave, let game = game, let newestSave = game.autoSaves.first else {
            return false
        }

        let isNewest = newestSave == self
        return isNewest
    }
}
