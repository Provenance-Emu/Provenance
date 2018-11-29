//
//  PVSaveState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVSupport

@objcMembers
public final class PVSaveState: Object {

    dynamic public var id = UUID().uuidString
    dynamic public var game: PVGame!
    dynamic public var core: PVCore!
    dynamic public var file: PVFile!
    dynamic public var date: Date = Date()
    dynamic public var lastOpened: Date?
    dynamic public var image: PVImageFile?
    dynamic public var isAutosave: Bool = false

    dynamic public var createdWithCoreVersion: String!

    public convenience init(withGame game: PVGame, core: PVCore, file: PVFile, image: PVImageFile? = nil, isAutosave: Bool = false) {
        self.init()
        self.game  = game
        self.file  = file
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

            try FileManager.default.removeItem(at: fileURL)
            if let imageURl = imageURl {
                try FileManager.default.removeItem(at: imageURl)
            }
        } catch {
            ELOG("Failed to delete PVState")
            throw error
        }
    }

    @objc dynamic public var isNewestAutosave : Bool {
        guard isAutosave, let game = game, let newestSave = game.autoSaves.first else {
            return false
        }

        let isNewest = newestSave == self
        return isNewest
    }

    public static func == (lhs: PVSaveState, rhs: PVSaveState) -> Bool {
        return lhs.file.url == rhs.file.url
    }

    override public static func primaryKey() -> String? {
        return "id"
    }
}

// MARK: - Conversions
fileprivate extension SaveState {
    init(with saveState : PVSaveState) {
        id = saveState.id
        game = saveState.game.asDomain()
        core = saveState.core.asDomain()
        file = FileInfo(fileName: saveState.file.fileName, size: saveState.file.size, md5: saveState.file.md5, online: saveState.file.online, local: true)
        date = saveState.date
        lastOpened = saveState.lastOpened

        if let sImage = saveState.image {
            image = LocalFile(url: sImage.url)
        } else {
            image = nil
        }
        isAutosave = saveState.isAutosave
    }
}

extension PVSaveState : DomainConvertibleType {
    public typealias DomainType = SaveState

    public func asDomain() -> SaveState {
        return SaveState(with: self)
    }
}

extension SaveState: RealmRepresentable {
    public var uid: String {
        return file.fileName
    }

    public func asRealm() -> PVSaveState {
        return PVSaveState.build { object in

            object.id = id
            let realm = try! Realm()
            let rmGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5)
//            let rmGame = game.asRealm()
            object.game = rmGame
            let rmCore = realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier)
            object.core = rmCore //core.asRealm()

            let dir = PVEmulatorConfiguration.saveStatePath(forGame: rmGame!)
            let path = dir.appendingPathComponent(file.fileName)
            object.file = PVFile(withURL: path)
            print("file path: \(path)")

            object.date = date
            object.lastOpened = lastOpened
            if let image = image {
                let path = dir.appendingPathComponent(image.fileName)
                print("path: \(path)")
                object.image = PVImageFile(withURL: path)
            }
            object.isAutosave = isAutosave
         }
    }
}
