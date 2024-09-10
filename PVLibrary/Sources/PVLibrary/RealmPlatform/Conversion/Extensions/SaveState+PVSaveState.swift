//
//  SaveState+PVSaveState.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import PVLibraryPrimitives
import RealmSwift

// MARK: - Conversions

public extension SaveState {
    init(with saveState: PVSaveState) {
        let id = saveState.id
        let game = saveState.game.asDomain()
        let core = saveState.core.asDomain()
        let file = FileInfo(fileName: saveState.file.fileName, size: saveState.file.size, md5: saveState.file.md5, online: saveState.file.online, local: true)
        let date = saveState.date
        let lastOpened = saveState.lastOpened

        let image: LocalFile?
        if let sImage = saveState.image {
            image = LocalFile(url: sImage.url)
        } else {
            image = nil
        }
        let isAutosave = saveState.isAutosave
        
        self.init(id: id, game: game, core: core, file: file, date: date, lastOpened: lastOpened, image: image, isAutosave: isAutosave)
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
