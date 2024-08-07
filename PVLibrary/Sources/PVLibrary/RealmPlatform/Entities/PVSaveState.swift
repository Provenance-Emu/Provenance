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

public protocol Filed {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

extension LocalFileProvider where Self: Filed {
    public var url: URL { get async { return await file.url } }
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

    public class func delete(_ state: PVSaveState) async throws {
        do {
            // Temp store these URLs
            let fileURL = await state.file.url
            let imageURl = await state.image?.url

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

    public static func == (lhs: PVSaveState, rhs: PVSaveState) async -> Bool {
        return await lhs.file.url == rhs.file.url
    }

    public override static func primaryKey() -> String? {
        return "id"
    }
}

// MARK: - Conversions

private extension SaveState {
    init(with saveState: PVSaveState) async {
        id = saveState.id
        game = await saveState.game.asDomain()
        core = await saveState.core.asDomain()
        file = await FileInfo(fileName: saveState.file.fileName, size: saveState.file.size, md5: saveState.file.md5, online: saveState.file.online, local: true)
        date = saveState.date
        lastOpened = saveState.lastOpened

        if let sImage = saveState.image {
            image = await LocalFile(url: sImage.url)
        } else {
            image = nil
        }
        isAutosave = saveState.isAutosave
    }
}

extension PVSaveState: DomainConvertibleType {
    public typealias DomainType = SaveState

    public func asDomain() async -> SaveState {
        return await SaveState(with: self)
    }
}

extension SaveState: RealmRepresentable {
    public var uid: String {
        return file.fileName
    }

    @MainActor
    public func asRealm() async -> PVSaveState {
        return await PVSaveState.build { object in

            object.id = id
            let realm = try! await Realm()
            
            if let rmGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5) {
                object.game = rmGame
            } else {
                object.game = await game.asRealm()
            }

            if let rmCore = realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier) {
                object.core = rmCore
            } else {
                object.core = await core.asRealm()
            }

            Task {
                let path = await PVEmulatorConfiguration.saveStatePath(forROMFilename: game.file.fileName).appendingPathComponent(file.fileName)
                object.file = await PVFile(withURL: path)
                DLOG("file path: \(path)")
                
                object.date = date
                object.lastOpened = lastOpened
                if let image = image {
                    let dir = path.deletingLastPathComponent()
                    let imagePath = await dir.appendingPathComponent(image.fileName)
                    DLOG("path: \(imagePath)")
                    object.image = await PVImageFile(withURL: imagePath, relativeRoot: .iCloud)
                }
                object.isAutosave = isAutosave
            }
        }
    }
}
