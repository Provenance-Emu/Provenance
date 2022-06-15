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

public protocol Filed {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

extension LocalFileProvider where Self: Filed {
    public var url: URL { return file.url }
    public var fileInfo: Self.LocalFileProviderType? { return file }
}

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

            try FileManager.default.removeItem(at: fileURL)
            if let imageURl = imageURl {
                try FileManager.default.removeItem(at: imageURl)
            }
        } catch {
            ELOG("Failed to delete PVState")
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

// MARK: - Conversions

private extension SaveState {
    init(with saveState: PVSaveState) {
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

extension PVSaveState: DomainConvertibleType {
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
            let rmGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5) ?? game.asRealm()
            object.game = rmGame
            let rmCore = realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier) ?? core.asRealm()
            object.core = rmCore

            let path = PVEmulatorConfiguration.saveStatePath(forROMFilename: game.file.fileName).appendingPathComponent(file.fileName)
            object.file = PVFile(withURL: path)
            DLOG("file path: \(path)")

            object.date = date
            object.lastOpened = lastOpened
            if let image = image {
                let dir = path.deletingLastPathComponent()
                let imagePath = dir.appendingPathComponent(image.fileName)
                DLOG("path: \(imagePath)")
                object.image = PVImageFile(withURL: imagePath)
            }
            object.isAutosave = isAutosave
        }
    }
}
