//
//  SaveState+PVSaveState.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import PVPrimitives
import RealmSwift
import RxRealm

// MARK: - Conversions

public extension SaveState {
    init(with saveState: PVSaveState) {
        let id = saveState.id
        let game = saveState.game.asDomain()
        let core = saveState.core.asDomain()
        let file = FileInfo(fileName: saveState.file?.fileName ?? "",
                            size: saveState.file?.size ?? 0,
                            md5: saveState.file?.md5 ?? "",
                            online: saveState.file?.online ?? true,
                            local: true)
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

    public func asRealm() -> PVSaveState {
        try! Realm().buildSaveState(from: self)
    }
}

public extension Realm {
    func buildSaveState(from save: SaveState) -> PVSaveState {
        return PVSaveState.build { object in
            object.id = save.id
            
            if let rmGame = self.object(ofType: PVGame.self, forPrimaryKey: save.game.md5) {
                object.game = rmGame
            } else {
                object.game = buildGame(from: save.game)
            }

            if let rmCore = self.object(ofType: PVCore.self, forPrimaryKey: save.core.identifier) {
                object.core = rmCore
            } else {
                object.core = buildCore(from: save.core)
            }
            //we remove the extension in order to get the correct path
            let path = save.game.file.fileName.saveStatePath.deletingPathExtension().appendingPathComponent(save.file.fileName)
            object.file = PVFile(withURL: path, relativeRoot: .iCloud)
            DLOG("file path: \(path)")
            
            object.date = save.date
            object.lastOpened = save.lastOpened
            if let image = save.image {
                let dir = path.deletingLastPathComponent()
                let imagePath = dir.appendingPathComponent(image.fileName)
                DLOG("path: \(imagePath)")
                object.image = PVImageFile(withURL: imagePath, relativeRoot: .iCloud)
            }
            object.isAutosave = save.isAutosave
        }
    }
}
