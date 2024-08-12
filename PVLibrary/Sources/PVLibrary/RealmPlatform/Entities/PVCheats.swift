//
//  PVCheats.swift
//  Provenance
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging

public protocol CheatFile {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

extension LocalFileProvider where Self: CheatFile {
    public var url: URL { get { return file.url }}
    public var fileInfo: Self.LocalFileProviderType? { get { return file }}
}

@objcMembers
public final class PVCheats: Object, CheatFile, LocalFileProvider {
    public dynamic var id = UUID().uuidString
    public dynamic var game: PVGame!
    public dynamic var core: PVCore!
    public dynamic var code: String!
    public dynamic var file: PVFile!
    public dynamic var date: Date = Date()
    public dynamic var lastOpened: Date?
    public dynamic var type: String!
    public dynamic var enabled: Bool = false

    public dynamic var createdWithCoreVersion: String!

    public convenience init(withGame game: PVGame, core: PVCore, code: String, type: String, enabled: Bool = false, file: PVFile ) {
        self.init()
        self.game = game
        self.code = code
        self.type = type
        self.enabled = enabled
        self.core = core
        self.file = file
        createdWithCoreVersion = core.projectVersion
    }

    public class func delete(_ state: PVCheats) throws {
        do {
            let database = RomDatabase.sharedInstance
            try database.delete(state)
        } catch {
            NSLog("Failed to delete PVState")
        }
    }

    public static func == (lhs: PVCheats, rhs: PVCheats) -> Bool {
        return lhs.code == rhs.code && lhs.type == rhs.type && lhs.enabled == rhs.enabled
    }

    public override static func primaryKey() -> String? {
        return "id"
    }
}

// MARK: - Conversions

private extension Cheats {
    init(with saveState: PVCheats) async {
        id = saveState.id
        game = await saveState.game.asDomain()
        core = await saveState.core.asDomain()
        code = saveState.code
        type = saveState.type
        date = saveState.date
        lastOpened = saveState.lastOpened
        enabled=saveState.enabled
        file = await FileInfo(fileName: saveState.file.fileName, size: saveState.file.size, md5: saveState.file.md5, online: saveState.file.online, local: true)
    }
}

extension PVCheats: DomainConvertibleType {
    public typealias DomainType = Cheats

    public func asDomain() async -> Cheats {
        return await Cheats(with: self)
    }
}

extension Cheats: RealmRepresentable {
    public var uid: String {
        return code
    }

    public func asRealm() async -> PVCheats {
        return await PVCheats.build { object in
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
            object.date = date
            let path = await PVEmulatorConfiguration.saveStatePath(forROMFilename: game.file.fileName).appendingPathComponent(file.fileName)
            object.file = await PVFile(withURL: path)
            object.lastOpened = lastOpened
            object.code=code
            object.type=type
            object.enabled=false
        }
    }
}
